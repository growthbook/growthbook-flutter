import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';
import 'package:growthbook_sdk_flutter/src/Utils/log_redaction.dart';

typedef VoidCallback = void Function();

typedef OnInitializationFailure = void Function(GBError? error);

class GBSDKBuilderApp {
  GBSDKBuilderApp(
      {required this.hostURL,
      required this.apiKey,
      this.encryptionKey,
      required this.growthBookTrackingCallBack,
      this.attributes = const <String, dynamic>{},
      this.qaMode = false,
      this.enable = true,
      this.forcedVariations = const <String, int>{},
      this.client,
      this.gbFeatures = const {},
      this.onInitializationFailure,
      this.refreshHandler,
      this.stickyBucketService,
      this.backgroundSync = false,
      this.remoteEval = false,
      this.ttlSeconds = 60,
      this.url});

  final String apiKey;
  final String? encryptionKey;
  final String hostURL;
  final bool enable;
  final bool qaMode;
  final Map<String, dynamic>? attributes;
  final Map<String, int> forcedVariations;
  final TrackingCallBack growthBookTrackingCallBack;
  final BaseClient? client;
  final GBFeatures gbFeatures;
  final OnInitializationFailure? onInitializationFailure;
  final bool backgroundSync;
  final bool remoteEval;
  final String? url;
  final int ttlSeconds;

  // ignore: deprecated_member_use_from_same_package
  CacheRefreshHandler? refreshHandler;
  CacheRefreshHandlerV2? refreshHandlerV2;
  StickyBucketService? stickyBucketService;
  GBFeatureUsageCallback? featureUsageCallback;
  final List<GrowthBookPlugin> _plugins = [];

  Future<GrowthBookSDK> initialize() async {
    _validateRemoteEval();

    final gbContext = GBContext(
        apiKey: apiKey,
        encryptionKey: encryptionKey,
        hostURL: hostURL,
        enabled: enable,
        qaMode: qaMode,
        attributes: attributes,
        forcedVariation: forcedVariations,
        trackingCallBack: growthBookTrackingCallBack,
        featureUsageCallback: featureUsageCallback,
        features: gbFeatures,
        stickyBucketService: stickyBucketService,
        backgroundSync: backgroundSync,
        remoteEval: remoteEval,
        url: url);
    final gb = GrowthBookSDK._(
        context: gbContext,
        client: client,
        onInitializationFailure: onInitializationFailure,
        refreshHandler: refreshHandler,
        refreshHandlerV2: refreshHandlerV2,
        pluginRegistry: PluginRegistry(_plugins),
        ttlSeconds: ttlSeconds);
    await gb.refresh();
    await gb.refreshStickyBucketService(null);
    gb._initializePlugins();
    return gb;
  }

  /// Rejects the remote-eval configurations the reference JS SDK rejects, and
  /// only those: an encryption key, a missing client key, and a GrowthBook
  /// Cloud host, which serves no remote-evaluation endpoint.
  ///
  /// Streaming and a sticky bucket service are deliberately not rejected — the
  /// reference SDK supports both alongside remote evaluation, and a streamed
  /// event is handled as a signal to re-evaluate remotely.
  void _validateRemoteEval() {
    if (!remoteEval) return;

    if (apiKey.isEmpty) {
      throw ArgumentError('remoteEval requires a non-empty apiKey');
    }
    if (encryptionKey != null) {
      throw ArgumentError('remoteEval is incompatible with encryptionKey');
    }
    // Matched against the hostname's suffix rather than anywhere in the URL, so
    // a host that merely contains the string — https://mygrowthbook.iodine.test
    // or a path segment — is not mistaken for the cloud API.
    final host = Uri.tryParse(hostURL)?.host.toLowerCase() ?? '';
    if (host.endsWith('growthbook.io')) {
      throw ArgumentError(
        'remoteEval requires a self-hosted GrowthBook proxy, not the cloud API',
      );
    }
  }

  /// Registers a legacy refresh handler that only receives a boolean.
  ///
  /// Prefer [setRefreshHandlerV2] which also receives the [GBError] that
  /// caused a failure.
  @Deprecated('Use setRefreshHandlerV2 for error-aware refresh callbacks')
  // ignore: deprecated_member_use_from_same_package
  GBSDKBuilderApp setRefreshHandler(CacheRefreshHandler refreshHandler) {
    this.refreshHandler = refreshHandler;
    return this;
  }

  /// Registers an error-aware refresh handler. Called with
  /// `(true, null)` on successful refresh and `(false, error)` on failure.
  GBSDKBuilderApp setRefreshHandlerV2(CacheRefreshHandlerV2 refreshHandlerV2) {
    this.refreshHandlerV2 = refreshHandlerV2;
    return this;
  }

  GBSDKBuilderApp setStickyBucketService(
      StickyBucketService? stickyBucketService) {
    this.stickyBucketService = stickyBucketService;
    return this;
  }

  /// Setter for featureUsageCallback. A callback that will be invoked every time a feature is viewed.
  GBSDKBuilderApp setFeatureUsageCallback(
      GBFeatureUsageCallback featureUsageCallback) {
    this.featureUsageCallback = featureUsageCallback;
    return this;
  }

  /// Registers a plugin that will receive experiment and feature evaluation events.
  GBSDKBuilderApp addPlugin(GrowthBookPlugin plugin) {
    _plugins.add(plugin);
    return this;
  }
}

/// The main export of the libraries is a simple GrowthBook wrapper class that
/// takes a Context object in the constructor.
/// It exposes two main methods: feature and run.
class GrowthBookSDK extends FeaturesFlowDelegate {
  GrowthBookSDK._({
    OnInitializationFailure? onInitializationFailure,
    required GBContext context,
    EvaluationContext? evaluationContext,
    BaseClient? client,
    // ignore: deprecated_member_use_from_same_package
    CacheRefreshHandler? refreshHandler,
    CacheRefreshHandlerV2? refreshHandlerV2,
    PluginRegistry? pluginRegistry,
    required int ttlSeconds,
  })  : _context = context,
        _evaluationContext =
            evaluationContext ?? GBUtils.initializeEvalContext(context, null),
        _onInitializationFailure = onInitializationFailure,
        _refreshHandler = refreshHandler,
        _refreshHandlerV2 = refreshHandlerV2,
        _baseClient = client ?? DioClient(),
        _pluginRegistry = pluginRegistry ?? PluginRegistry.empty,
        _forcedFeatures = [],
        _attributeOverrides = {} {
    _featureViewModel = FeatureViewModel(
        delegate: this,
        source: FeatureDataSource(context: _context, client: _baseClient),
        encryptionKey: _context.encryptionKey ?? "",
        backgroundSync: _context.backgroundSync,
        ttlSeconds: ttlSeconds,
        // Only set in remote-eval mode, which is what puts the view model in
        // that mode; the provider is invoked per round so every request carries
        // the evaluation inputs as they are at that moment.
        remoteEvalRequestProvider:
            _context.remoteEval ? _buildRemoteEvalRequest : null);
    autoRefresh();
  }

  final GBContext _context;

  EvaluationContext _evaluationContext;

  late FeatureViewModel _featureViewModel;

  final BaseClient _baseClient;

  final OnInitializationFailure? _onInitializationFailure;

  // ignore: deprecated_member_use_from_same_package
  final CacheRefreshHandler? _refreshHandler;

  final CacheRefreshHandlerV2? _refreshHandlerV2;

  final PluginRegistry _pluginRegistry;

  List<dynamic> _forcedFeatures;

  Map<String, dynamic> _attributeOverrides;

  List<ExperimentRunCallback> subscriptions = [];

  Map<String, AssignedExperiment> assigned = {};

  /// The complete data regarding features & attributes etc.
  GBContext get context => _context;

  /// Retrieved features.
  dynamic get features => _context.features;

  /// Updates the evaluation context to reflect current context state.
  /// This method should be called whenever the underlying GBContext changes
  /// to ensure that the evaluation context remains synchronized.
  ///
  /// This approach maintains a single source of truth for the evaluation context
  /// instead of creating new contexts on every evaluation, which is more efficient
  /// and prevents bugs caused by stale evaluation contexts.
  void _updateEvaluationContext() {
    _evaluationContext =
        GBUtils.initializeEvalContext(_context, _refreshHandler);
  }

  void _initializePlugins() {
    _pluginRegistry.initialize(_context.apiKey ?? '');
  }

  /// Releases resources held by all registered plugins.
  ///
  /// **Always await this** when the SDK instance is no longer needed —
  /// tracking plugins buffer events in memory and rely on `close()` to flush
  /// them. Without an awaited `dispose()`, queued events are dropped when the
  /// app terminates.
  ///
  /// Typical usage:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   sdk.dispose();
  ///   super.dispose();
  /// }
  /// ```
  ///
  /// For short-lived scripts, wrap in try/finally:
  /// ```dart
  /// try {
  ///   // ... SDK usage
  /// } finally {
  ///   await sdk.dispose();
  /// }
  /// ```
  Future<void> dispose() {
    return _pluginRegistry.close();
  }

  @override
  void featuresFetchedSuccessfully({
    required GBFeatures gbFeatures,
    required bool isRemote,
  }) {
    _context.features = gbFeatures;
    _updateEvaluationContext();
    if (isRemote) {
      log('Features updated from remote source, triggering refresh handler');
      _refreshHandler?.call(true);
      _refreshHandlerV2?.call(true, null);
    }
  }

  @override
  void featuresNotModified() {
    _refreshHandler?.call(true);
    _refreshHandlerV2?.call(true, null);
  }

  @override
  void featuresFetchFailed({required GBError? error, required bool isRemote}) {
    _onInitializationFailure?.call(error);
    if (isRemote) {
      _refreshHandler?.call(false);
      _refreshHandlerV2?.call(false, error);
    }
  }

  Future<void> autoRefresh() async {
    if (_context.backgroundSync) {
      await _featureViewModel.connectBackgroundSync();
    }
  }

  Future<void> refresh() async {
    if (_context.remoteEval) {
      await refreshForRemoteEval();
    } else {
      log('Fetching features from ${redactUrl(context.getFeaturesURL())}');
      await _featureViewModel.fetchFeatures(context.getFeaturesURL());
    }
  }

  Map<String, GBExperimentResult> getAllResults() {
    final Map<String, GBExperimentResult> results = {};

    for (var entry in assigned.entries) {
      final experimentKey = entry.key;
      final experimentResult = entry.value.experimentResult;
      results[experimentKey] = experimentResult;
    }

    return results;
  }

  void fireSubscriptions(GBExperiment experiment, GBExperimentResult result) {
    String key = experiment.key;
    AssignedExperiment? prevAssignedExperiment = assigned[key];
    if (prevAssignedExperiment == null ||
        prevAssignedExperiment.experimentResult.inExperiment !=
            result.inExperiment ||
        prevAssignedExperiment.experimentResult.variationID !=
            result.variationID) {
      updateSubscriptions(key: key, experiment: experiment, result: result);
    }
  }

  void updateSubscriptions(
      {required String key,
      required GBExperiment experiment,
      required GBExperimentResult result}) {
    assigned[key] =
        AssignedExperiment(experiment: experiment, experimentResult: result);
    for (var subscription in subscriptions) {
      subscription(experiment, result);
    }
  }

  Function subscribe(ExperimentRunCallback callback) {
    subscriptions.add(callback);
    return () {
      subscriptions.remove(callback);
    };
  }

  void clearSubscriptions() {
    subscriptions.clear();
  }

  GBFeatureResult feature(String id) {
    _triggerBackgroundRefreshIfNeeded();
    _evaluationContext.stackContext.evaluatedFeatures.clear();
    final result = FeatureEvaluator().evaluateFeature(_evaluationContext, id);
    _notifyFeatureEvaluated(id, result);
    // Propagate any newly persisted sticky bucket assignments back to the
    // shared GBContext so the next _updateEvaluationContext() preserves them.
    _context.stickyBucketAssignmentDocs =
        _evaluationContext.userContext.stickyBucketAssignmentDocs;
    return result;
  }

  void _triggerBackgroundRefreshIfNeeded() {
    if (!_context.backgroundSync && _featureViewModel.isCacheExpired()) {
      // Fire and forget - don't block feature evaluation

      if (_context.remoteEval) {
        refreshForRemoteEval().catchError((Object e) {
          log('Background refresh failed: ${describeRequestError(e)}');
        });
      } else {
        _featureViewModel
            .fetchFeatures(context.getFeaturesURL())
            .catchError((Object e) {
          log('Background refresh failed: ${describeRequestError(e)}');
        });
      }
    }
  }

  GBExperimentResult run(GBExperiment experiment) {
    // Sync features to evaluation context (no fetchFeatures to avoid cycles)
    _evaluationContext.globalContext.features = _context.features;
    // Clear stack context to avoid false cyclic prerequisite detection
    _evaluationContext.stackContext.evaluatedFeatures.clear();
    final result = ExperimentEvaluator().evaluateExperiment(
      _evaluationContext,
      experiment,
    );
    _context.stickyBucketAssignmentDocs =
        _evaluationContext.userContext.stickyBucketAssignmentDocs;
    fireSubscriptions(experiment, result);
    if (result.inExperiment) {
      _notifyExperimentViewed(experiment, result);
    }
    return result;
  }

  Map<StickyAttributeKey, StickyAssignmentsDocument>
      getStickyBucketAssignmentDocs() {
    return _context.stickyBucketAssignmentDocs ?? {};
  }

  /// Replaces the Map of user attributes that are used to assign variations.
  ///
  /// This is a full **replace**: any previously set attribute that is missing
  /// from [attributes] is dropped. Use [updateAttributes] to merge into the
  /// existing attributes instead.
  ///
  /// Sticky bucket refresh runs in the background (fire-and-forget).
  /// If you use Sticky Bucketing and need to guarantee that assignments are
  /// loaded before evaluating experiments (e.g. after login or user switch),
  /// use [setAttributesAsync] instead.
  ///
  /// In remote-eval mode attributes are part of the evaluation payload, so
  /// changing them makes the cached response stale — a fresh remote evaluation
  /// is triggered in the background.
  void setAttributes(Map<String, dynamic> attributes) {
    _context.attributes = attributes;
    _updateEvaluationContext();
    refreshStickyBucketService(null);
    refreshForRemoteEval();
  }

  /// Async version of [setAttributes] that awaits sticky bucket refresh
  /// before returning. Use this when you rely on Sticky Bucketing and need
  /// assignments to be loaded before evaluating experiments:
  /// ```dart
  /// await sdk.setAttributesAsync(loginAttributes);
  /// final result = sdk.feature('my-experiment'); // sticky buckets guaranteed
  /// ```
  ///
  /// In remote-eval mode the refetch triggered by the new attributes is
  /// awaited as well.
  Future<void> setAttributesAsync(Map<String, dynamic> attributes) async {
    _context.attributes = attributes;
    _updateEvaluationContext();
    await refreshStickyBucketService(null);
    await refreshForRemoteEval();
  }

  /// Merges [attributes] into the existing user attributes instead of
  /// replacing them (parity with the JS/TS SDK's `updateAttributes`).
  ///
  /// New keys are added, existing keys are overwritten and keys that are not
  /// present in [attributes] are preserved:
  /// ```dart
  /// sdk.setAttributes({'id': '1'});
  /// sdk.updateAttributes({'plan': 'pro'}); // {'id': '1', 'plan': 'pro'}
  /// ```
  ///
  /// The merge is shallow — a nested Map or List replaces the previous value of
  /// that key instead of being merged recursively. A `null` value is stored as
  /// `null`; it does not remove the key. An empty Map is a no-op.
  ///
  /// Sticky bucket refresh runs in the background (fire-and-forget); use
  /// [updateAttributesAsync] when assignments must be loaded before evaluating.
  /// In remote-eval mode a fresh remote evaluation is triggered, because
  /// attributes are part of the evaluation payload.
  void updateAttributes(Map<String, dynamic> attributes) {
    _context.attributes = _mergedAttributes(attributes);
    _updateEvaluationContext();
    refreshStickyBucketService(null);
    refreshForRemoteEval();
  }

  /// Async version of [updateAttributes] that awaits the sticky bucket refresh
  /// and, in remote-eval mode, the refetch before returning.
  /// See [setAttributesAsync].
  Future<void> updateAttributesAsync(Map<String, dynamic> attributes) async {
    _context.attributes = _mergedAttributes(attributes);
    _updateEvaluationContext();
    await refreshStickyBucketService(null);
    await refreshForRemoteEval();
  }

  /// Builds a new Map with [attributes] shallow-merged over the current ones.
  ///
  /// The merged Map is built off to the side and assigned in a single step, so
  /// an evaluation running between two updates always sees either the previous
  /// or the fully merged attributes, never a partially merged state.
  Map<String, dynamic> _mergedAttributes(Map<String, dynamic> attributes) {
    return <String, dynamic>{
      ...?_context.attributes,
      ...attributes,
    };
  }

  /// Gets the current attribute overrides
  Map<String, dynamic> get attributeOverrides => _attributeOverrides;

  /// Replaces attribute overrides used during experiment evaluation.
  ///
  /// Sticky bucket refresh runs in the background (fire-and-forget).
  /// If you use Sticky Bucketing, use [setAttributeOverridesAsync] instead.
  void setAttributeOverrides(dynamic overrides) {
    _attributeOverrides = jsonDecode(overrides) as Map<String, dynamic>;
    _updateEvaluationContext();
    if (context.stickyBucketService != null) {
      refreshStickyBucketService(null);
    }
    refreshForRemoteEval();
  }

  /// Async version of [setAttributeOverrides] that awaits sticky bucket
  /// refresh before returning.
  Future<void> setAttributeOverridesAsync(dynamic overrides) async {
    _attributeOverrides = jsonDecode(overrides) as Map<String, dynamic>;
    _updateEvaluationContext();
    if (context.stickyBucketService != null) {
      await refreshStickyBucketService(null);
    }
    refreshForRemoteEval();
  }

  /// The setForcedFeatures method updates forced features
  ///
  /// Forced features are part of the remote-evaluation payload, so in
  /// remote-eval mode changing them triggers a fresh evaluation in the
  /// background — otherwise the server would keep evaluating against the
  /// previous forced values.
  void setForcedFeatures(List<dynamic> forcedFeatures) {
    _forcedFeatures = forcedFeatures;
    _updateEvaluationContext();
    refreshForRemoteEval();
  }

  void setEncryptedFeatures(String encryptedString, String encryptionKey,
      [CryptoProtocol? subtle]) {
    CryptoProtocol crypto = subtle ?? Crypto();
    var features = crypto.getFeaturesFromEncryptedFeatures(
      encryptedString,
      encryptionKey,
    );

    if (features != null) {
      _context.features = features;
      _updateEvaluationContext();
      // New features may reference different hash/fallback attributes —
      // refresh sticky bucket docs so the next eval works against current
      // identifiers.
      refreshStickyBucketService(null);
    }
  }

  void setForcedVariations(Map<String, dynamic> forcedVariations) {
    _context.forcedVariation = forcedVariations;
    _updateEvaluationContext();
    // Forced variations are evaluated against sticky bucket assignments —
    // refresh so docs reflect the updated forced map.
    refreshStickyBucketService(null);
    refreshForRemoteEval();
  }

  Future<void> setUrl(String url) async {
    _context.url = url;
    if (_context.remoteEval) {
      await refreshForRemoteEval();
    }
  }

  @override
  Future<void> featuresAPIModelSuccessfully(FeaturedDataModel model) async {
    await refreshStickyBucketService(model);
  }

  Future<void> refreshStickyBucketService(FeaturedDataModel? data) async {
    if (context.stickyBucketService != null) {
      await GBUtils.refreshStickyBuckets(
        _context,
        data,
        _evaluationContext.userContext.attributes ?? {},
        _attributeOverrides,
        experiments: _evaluationContext.globalContext.experiments,
      );
      _updateEvaluationContext();
    }
  }

  /// Builds the request for the next remote-evaluation round from the current
  /// evaluation inputs. Passed to the view model as a provider, so a round that
  /// starts later (a refresh after an attribute change, a streamed update) sends
  /// the state as it is then.
  RemoteEvalRequest? _buildRemoteEvalRequest() {
    final apiUrl = context.getRemoteEvalUrl();
    // No usable URL (host or client key missing) — nothing to evaluate against.
    if (apiUrl == null) return null;

    return RemoteEvalRequest(
      apiUrl: apiUrl,
      payload: RemoteEvalModel(
        attributes: _evaluationContext.userContext.attributes ?? {},
        forcedFeatures: _forcedFeatures,
        forcedVariations:
            _evaluationContext.userContext.forcedVariationsMap ?? {},
      ),
    );
  }

  Future<void> refreshForRemoteEval() async {
    if (!context.remoteEval) return;
    await _featureViewModel.fetchFeatures(context.getRemoteEvalUrl());
  }

  /// The evalFeature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.
  GBFeatureResult evalFeature(String id) {
    // Sync features to evaluation context (no fetchFeatures to avoid cycles)
    _evaluationContext.globalContext.features = _context.features;
    // Clear stack context to avoid false cyclic prerequisite detection
    _evaluationContext.stackContext.evaluatedFeatures.clear();
    final result = FeatureEvaluator().evaluateFeature(_evaluationContext, id);
    _notifyFeatureEvaluated(id, result);
    _context.stickyBucketAssignmentDocs =
        _evaluationContext.userContext.stickyBucketAssignmentDocs;
    return result;
  }

  void _notifyFeatureEvaluated(String id, GBFeatureResult result) {
    _pluginRegistry.onFeatureEvaluated(id, result, _context.attributes);
  }

  void _notifyExperimentViewed(
      GBExperiment experiment, GBExperimentResult result) {
    _pluginRegistry.onExperimentViewed(experiment, result, _context.attributes);
  }

  /// The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off
  bool isOn(String id) {
    return evalFeature(id).on;
  }

  @override
  void savedGroupsFetchFailed(
      {required GBError? error, required bool isRemote}) {
    _onInitializationFailure?.call(error);
    if (isRemote) {
      _refreshHandler?.call(false);
      _refreshHandlerV2?.call(false, error);
    }
  }

  @override
  void savedGroupsFetchedSuccessfully(
      {required SavedGroupsValues savedGroups, required bool isRemote}) {
    _context.savedGroups = savedGroups;
    _updateEvaluationContext();
    if (isRemote) {
      _refreshHandler?.call(true);
      _refreshHandlerV2?.call(true, null);
    }
  }
}
