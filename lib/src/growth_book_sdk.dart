import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';

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

  Future<GrowthBookSDK> initialize() async {
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
        ttlSeconds: ttlSeconds);
    await gb.refresh();
    await gb.refreshStickyBucketService(null);
    return gb;
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
    required int ttlSeconds,
  })  : _context = context,
        _evaluationContext =
            evaluationContext ?? GBUtils.initializeEvalContext(context, null),
        _onInitializationFailure = onInitializationFailure,
        _refreshHandler = refreshHandler,
        _refreshHandlerV2 = refreshHandlerV2,
        _baseClient = client ?? DioClient(),
        _forcedFeatures = [],
        _attributeOverrides = {} {
    _featureViewModel = FeatureViewModel(
        delegate: this,
        source: FeatureDataSource(context: _context, client: _baseClient),
        encryptionKey: _context.encryptionKey ?? "",
        backgroundSync: _context.backgroundSync,
        ttlSeconds: ttlSeconds);
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
      log(context.getFeaturesURL().toString());
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
        refreshForRemoteEval().catchError((e) {
          log('Background refresh failed: $e');
        });
      } else {
        _featureViewModel
            .fetchFeatures(context.getFeaturesURL())
            .catchError((e) {
          log('Background refresh failed: $e');
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
    return result;
  }

  Map<StickyAttributeKey, StickyAssignmentsDocument>
      getStickyBucketAssignmentDocs() {
    return _context.stickyBucketAssignmentDocs ?? {};
  }

  /// Replaces the Map of user attributes that are used to assign variations.
  ///
  /// Sticky bucket refresh runs in the background (fire-and-forget).
  /// If you use Sticky Bucketing and need to guarantee that assignments are
  /// loaded before evaluating experiments (e.g. after login or user switch),
  /// use [setAttributesAsync] instead.
  void setAttributes(Map<String, dynamic> attributes) {
    _context.attributes = attributes;
    _updateEvaluationContext();
    refreshStickyBucketService(null);
  }

  /// Async version of [setAttributes] that awaits sticky bucket refresh
  /// before returning. Use this when you rely on Sticky Bucketing and need
  /// assignments to be loaded before evaluating experiments:
  /// ```dart
  /// await sdk.setAttributesAsync(loginAttributes);
  /// final result = sdk.feature('my-experiment'); // sticky buckets guaranteed
  /// ```
  Future<void> setAttributesAsync(Map<String, dynamic> attributes) async {
    _context.attributes = attributes;
    _updateEvaluationContext();
    await refreshStickyBucketService(null);
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
  void setForcedFeatures(List<dynamic> forcedFeatures) {
    _forcedFeatures = forcedFeatures;
    _updateEvaluationContext();
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

  Future<void> refreshForRemoteEval() async {
    if (!context.remoteEval) return;
    RemoteEvalModel payload = RemoteEvalModel(
      attributes: _evaluationContext.userContext.attributes ?? {},
      forcedFeatures: _forcedFeatures,
      forcedVariations:
          _evaluationContext.userContext.forcedVariationsMap ?? {},
    );

    await _featureViewModel.fetchFeatures(
      context.getRemoteEvalUrl(),
      remoteEval: context.remoteEval,
      payload: payload,
    );
  }

  /// The evalFeature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.
  GBFeatureResult evalFeature(String id) {
    // Sync features to evaluation context (no fetchFeatures to avoid cycles)
    _evaluationContext.globalContext.features = _context.features;
    // Clear stack context to avoid false cyclic prerequisite detection
    _evaluationContext.stackContext.evaluatedFeatures.clear();
    final result = FeatureEvaluator().evaluateFeature(_evaluationContext, id);
    _context.stickyBucketAssignmentDocs =
        _evaluationContext.userContext.stickyBucketAssignmentDocs;
    return result;
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
