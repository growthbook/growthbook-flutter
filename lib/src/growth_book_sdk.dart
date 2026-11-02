import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Evaluator/experiment_helper.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';
import 'package:growthbook_sdk_flutter/src/Utils/poll_backoff.dart';

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
      this.url,
      this.pollingInterval});

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

  /// How often [GrowthBookSDK.startPolling] refreshes features.
  ///
  /// Configuring it does not start anything: polling is driven by
  /// [GrowthBookSDK.startPolling] and [GrowthBookSDK.stopPolling] so the app can
  /// tie it to its lifecycle, rather than leaving a timer running where the
  /// system will suspend the requests anyway.
  final Duration? pollingInterval;

  // ignore: deprecated_member_use_from_same_package
  CacheRefreshHandler? refreshHandler;
  CacheRefreshHandlerV2? refreshHandlerV2;
  StickyBucketService? stickyBucketService;
  GBFeatureUsageCallback? featureUsageCallback;
  final List<GrowthBookPlugin> _plugins = [];

  Future<GrowthBookSDK> initialize() async {
    final interval = pollingInterval;
    if (interval != null && interval <= Duration.zero) {
      // Rejected rather than clamped: a zero or negative interval is a typo,
      // and spinning on it would hammer the API.
      throw ArgumentError.value(
        interval,
        'pollingInterval',
        'must be greater than zero',
      );
    }

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
        ttlSeconds: ttlSeconds,
        pollingInterval: pollingInterval);
    await gb.refresh();
    await gb.refreshStickyBucketService(null);
    gb._initializePlugins();
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
    Duration? pollingInterval,
  })  : _context = context,
        _pollingInterval = pollingInterval,
        _evaluationContext =
            evaluationContext ?? GBUtils.initializeEvalContext(context, null),
        _onInitializationFailure = onInitializationFailure,
        _refreshHandler = refreshHandler,
        _refreshHandlerV2 = refreshHandlerV2,
        _baseClient = client ?? DioClient(),
        _pluginRegistry = pluginRegistry ?? PluginRegistry.empty,
        _forcedFeatures = [],
        _attributeOverrides = {} {
    // The initializer list cannot reach `_pluginRegistry`, and a caller may
    // have supplied its own evaluation context, so the registry and the
    // exposure history are attached here instead of being passed to
    // `initializeEvalContext` above.
    _evaluationContext.options.pluginRegistry = _pluginRegistry;
    _evaluationContext.options.experimentHelper = _experimentHelper;
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

  final PluginRegistry _pluginRegistry;

  /// Exposures this instance has already reported. Outlives every evaluation
  /// context rebuild, so an attribute update does not re-report them.
  final ExperimentHelper _experimentHelper = ExperimentHelper();

  final Duration? _pollingInterval;

  /// Scheduled next poll, or null while polling is stopped.
  Timer? _pollTimer;

  /// Consecutive failed rounds, which drive the backoff.
  int _pollFailures = 0;

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
    _evaluationContext = GBUtils.initializeEvalContext(
        _context, _refreshHandler,
        pluginRegistry: _pluginRegistry, experimentHelper: _experimentHelper);
  }

  void _initializePlugins() {
    _pluginRegistry.initialize(_context.apiKey ?? '');
  }

  /// Records an event of the app's own, alongside the exposures and
  /// evaluations the SDK tracks by itself.
  ///
  /// Buffered and batched like every other event, so it is subject to the same
  /// loss on termination — call [flush] when the app goes to the background.
  /// Unlike the SDK's own events these are never deduplicated: a repeat is a
  /// second occurrence, not a redundant re-evaluation.
  ///
  /// ```dart
  /// sdk.logEvent('Checkout Completed', {'total': 42.0});
  /// ```
  void logEvent(String eventName, [Map<String, dynamic>? properties]) {
    _pluginRegistry.logEvent(eventName, properties, _context.attributes);
  }

  /// Delivers whatever the registered plugins have buffered, leaving them
  /// running.
  ///
  /// Call this when the app is heading to the background. Nothing else
  /// delivers early: the tracking plugin batches for up to its `batchTimeout`,
  /// and a process the OS kills while suspended never reaches [dispose], so
  /// those events are simply lost.
  ///
  /// Unlike [dispose], recording resumes afterwards.
  ///
  /// ```dart
  /// @override
  /// void didChangeAppLifecycleState(AppLifecycleState state) {
  ///   if (state == AppLifecycleState.paused) sdk.flush();
  /// }
  /// ```
  Future<void> flush() {
    return _pluginRegistry.flush();
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
    stopPolling();
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

  /// Whether a poll is currently scheduled.
  bool get isPolling => _pollTimer != null;

  /// Starts refreshing features on the configured `pollingInterval`, and reports
  /// whether polling is now running.
  ///
  /// Streaming is the cheaper way to stay current, but it is not always
  /// available — a proxy or firewall that blocks SSE leaves a `backgroundSync`
  /// client with no updates at all, and on mobile a stream does not survive the
  /// app being backgrounded. Polling refreshes on a timer instead.
  ///
  /// Nothing starts on its own: tie this to the app lifecycle so the timer does
  /// not spend battery on requests the system will suspend anyway.
  /// ```dart
  /// @override
  /// void didChangeAppLifecycleState(AppLifecycleState state) {
  ///   state == AppLifecycleState.resumed ? sdk.startPolling() : sdk.stopPolling();
  /// }
  /// ```
  ///
  /// Returns false, and starts nothing, when no interval is configured or when
  /// `backgroundSync` is on: both reach the same endpoint and the stream is
  /// cheaper, so enabling both is safe rather than doubling the traffic.
  ///
  /// Each round ignores `ttlSeconds` — a cache-fresh round would issue no
  /// request, leaving the loop looking alive while doing nothing — and a failing
  /// host is backed off exponentially with jitter, capped at five minutes.
  bool startPolling() {
    final interval = _pollingInterval;
    if (interval == null) {
      log('Polling not started: no pollingInterval is configured');
      return false;
    }
    if (_context.backgroundSync) {
      log('Polling not started: streaming is already keeping features current');
      return false;
    }
    if (isPolling) return true;

    _pollFailures = 0;
    _scheduleNextPoll(interval);
    return true;
  }

  /// Stops polling. Safe to call when it is not running.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollFailures = 0;
  }

  void _scheduleNextPoll(Duration delay) {
    late final Timer timer;
    timer = Timer(delay, () async {
      final succeeded = await _pollOnce();
      // A Timer that has already fired cannot be cancelled, so the round has to
      // ask whether it is still the current one rather than whether any timer
      // is scheduled. stopPolling() and then startPolling() while this round
      // was awaiting the network - a quick inactive -> resumed - leaves this
      // callback holding a stale timer, and scheduling from here would run a
      // second loop alongside the new one for the rest of the process.
      if (!identical(_pollTimer, timer)) return;
      _pollFailures = succeeded ? 0 : _pollFailures + 1;
      _scheduleNextPoll(
        pollBackoffDelay(_pollingInterval!, _pollFailures),
      );
    });
    _pollTimer = timer;
  }

  /// Runs one round and reports whether it ended with usable definitions.
  Future<bool> _pollOnce() async {
    try {
      return _context.remoteEval
          ? await _featureViewModel.fetchFeatures(
              context.getRemoteEvalUrl(),
              remoteEval: true,
              payload: _buildRemoteEvalPayload(),
              force: true,
            )
          : await _featureViewModel.fetchFeatures(
              context.getFeaturesURL(),
              force: true,
            );
    } catch (e) {
      // A round must never take the loop down with it: one outage cannot stop a
      // client refreshing for the rest of its life.
      log('Poll failed: ${e.runtimeType}');
      return false;
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
        refreshForRemoteEval().catchError((e) {
          log('Background refresh failed: $e');
        });
      } else {
        _featureViewModel
            .fetchFeatures(context.getFeaturesURL())
            .catchError((Object e) {
          log('Background refresh failed: $e');
          return false;
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
    // Plugins are notified by [ExperimentEvaluator] itself, so that exposures
    // from feature flag rules are recorded too.
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

  /// Builds the remote-evaluation payload from the current evaluation inputs.
  RemoteEvalModel _buildRemoteEvalPayload() {
    return RemoteEvalModel(
      attributes: _evaluationContext.userContext.attributes ?? {},
      forcedFeatures: _forcedFeatures,
      forcedVariations:
          _evaluationContext.userContext.forcedVariationsMap ?? {},
    );
  }

  Future<void> refreshForRemoteEval() async {
    if (!context.remoteEval) return;

    await _featureViewModel.fetchFeatures(
      context.getRemoteEvalUrl(),
      remoteEval: context.remoteEval,
      payload: _buildRemoteEvalPayload(),
    );
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
