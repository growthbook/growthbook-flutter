import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:growthbook_sdk_flutter/src/Utils/log_redaction.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Plugins/dedupe_cache.dart';

/// An event waiting in the buffer: its encoded payload, and the key it took in
/// the dedupe cache so a failed send can give it back.
typedef _QueuedEvent = ({String json, String? dedupeKey});

/// Configuration for [GrowthBookTrackingPlugin].
class GrowthBookTrackingPluginConfig {
  const GrowthBookTrackingPluginConfig({
    this.ingestorHost = defaultIngestorHost,
    this.batchSize = defaultBatchSize,
    this.batchTimeout = defaultBatchTimeout,
    this.dedupeCacheSize = defaultDedupeCacheSize,
    this.enableFeatureUsageEvents = true,
  });

  static const String defaultIngestorHost = 'https://us1.gb-ingest.com';
  static const int defaultBatchSize = 100;
  static const Duration defaultBatchTimeout = Duration(seconds: 10);
  static const int defaultDedupeCacheSize = 1000;

  final String ingestorHost;
  final int batchSize;
  final Duration batchTimeout;

  /// How many recent event keys to remember when suppressing duplicates. Zero
  /// turns deduplication off and sends every evaluation.
  final int dedupeCacheSize;

  /// When false, feature evaluations stop being reported. Experiment exposures
  /// and events raised through [GrowthBookSDK.logEvent] are unaffected — an app
  /// that only needs exposures can drop the far larger volume of usage events
  /// without losing its experiment data.
  final bool enableFeatureUsageEvents;
}

/// A built-in GrowthBook plugin that batches experiment and feature evaluation
/// events and POSTs them to the GrowthBook ingest endpoint.
///
/// **Wire contract**
/// - Endpoint:  POST `{config.ingestorHost}/track?client_key={clientKey}`
/// - Body: a plain JSON array of ingest payloads
/// - Headers: `Content-Type: application/json`, `User-Agent: growthbook-flutter-sdk/{version}`
///
/// If initialized with an empty `clientKey` the plugin degrades to a no-op.
class GrowthBookTrackingPlugin extends GrowthBookPlugin {
  GrowthBookTrackingPlugin({
    GrowthBookTrackingPluginConfig config =
        const GrowthBookTrackingPluginConfig(),
    Dio? dio,
  })  : _config = config,
        _dio = dio ?? Dio(),
        _dedupeCache = DedupeCache(config.dedupeCacheSize);

  final GrowthBookTrackingPluginConfig _config;
  final Dio _dio;
  final DedupeCache _dedupeCache;

  String _clientKey = '';
  bool _isInitialized = false;

  /// Events already encoded to JSON when they were enqueued.
  ///
  /// The attributes handed to the plugin are the SDK's live map, and the
  /// properties of a custom event are whatever map the app passed in, so
  /// holding the event and encoding it at flush time read whatever those maps
  /// held then: a user switch before the batch went out relabelled the earlier
  /// user's events, and an app reusing one properties map overwrote its
  /// earlier events. Encoding up front freezes each event as it was, nested
  /// values included.
  final List<_QueuedEvent> _eventQueue = [];
  Timer? _flushTimer;

  // ---------------------------------------------------------------------------
  // GrowthBookPlugin
  // ---------------------------------------------------------------------------

  @override
  void initialize(String clientKey) {
    if (clientKey.isEmpty) return;
    _clientKey = clientKey;
    _isInitialized = true;
    _startTimer();
  }

  @override
  void onExperimentViewed(
    GBExperiment experiment,
    GBExperimentResult result,
    Map<String, dynamic>? attributes,
  ) {
    if (!_isInitialized) return;
    _enqueue(
        GBExperimentViewedEvent.from(experiment, result, attributes ?? {}));
  }

  @override
  void onFeatureEvaluated(
    String featureKey,
    GBFeatureResult result,
    Map<String, dynamic>? attributes,
  ) {
    if (!_config.enableFeatureUsageEvents) return;
    if (!_isInitialized) return;
    _enqueue(
        GBFeatureEvaluatedEvent.from(featureKey, result, attributes ?? {}));
  }

  @override
  void logEvent(
    String eventName,
    Map<String, dynamic>? properties,
    Map<String, dynamic>? attributes,
  ) {
    if (!_isInitialized) return;
    _enqueue(GBCustomEvent.from(eventName, properties, attributes ?? {}));
  }

  /// Sends what is buffered and leaves the timer running, so recording resumes
  /// as normal afterwards.
  @override
  Future<void> flush() => _flushSync();

  /// Stops the flush timer and sends all buffered events before returning.
  ///
  /// The plugin goes inert: anything evaluated afterwards is dropped rather
  /// than buffered for a batch nobody will send.
  @override
  Future<void> close() async {
    _stopTimer();
    _isInitialized = false;
    await _flushSync();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _enqueue(GBIngestEvent event) {
    // A flag that is read on every screen produces the same evaluation over and
    // over; sending each one costs bandwidth and tells the ingestor nothing it
    // did not already have.
    final key = event.dedupeKey;
    if (key != null && _dedupeCache.insertAndReportDuplicate(key)) return;

    final String json;
    try {
      json = jsonEncode(event.toJson());
    } catch (e) {
      // An attribute that is not JSON-encodable costs this event only, rather
      // than failing the whole batch at send time. Its key goes back, or the
      // event could never be reported once the attribute is fixed.
      if (key != null) _dedupeCache.remove(key);
      log('GrowthBookTrackingPlugin: dropped an event that cannot be '
          'encoded: $e');
      return;
    }
    _eventQueue.add((json: json, dedupeKey: key));
    if (_eventQueue.length >= _config.batchSize) {
      _flushAsync();
    }
  }

  void _startTimer() {
    _flushTimer = Timer.periodic(_config.batchTimeout, (_) => _flushAsync());
  }

  void _stopTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  void _flushAsync() {
    final events = _drainQueue();
    if (events.isEmpty) return;
    _post(events);
  }

  Future<void> _flushSync() async {
    final events = _drainQueue();
    if (events.isEmpty) return;
    await _post(events);
  }

  List<_QueuedEvent> _drainQueue() {
    final events = List<_QueuedEvent>.from(_eventQueue);
    _eventQueue.clear();
    return events;
  }

  Future<void> _post(List<_QueuedEvent> events) async {
    final url = '${_config.ingestorHost}/track?client_key=$_clientKey';

    // The keys were recorded when these events were accepted, before anything
    // was known about whether they would arrive. A batch that never lands has
    // to give them back, or the evaluations it carried stay suppressed — and
    // because re-evaluating one refreshes its place in the cache, they would
    // never age out either.
    final dedupeKeys =
        events.map((event) => event.dedupeKey).whereType<String>();

    try {
      await _dio.post<void>(
        url,
        data: '[${events.map((event) => event.json).join(',')}]',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'growthbook-flutter-sdk/$gbSdkVersion',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      // Dio treats any non-2xx as an error, so a batch the ingestor rejected
      // lands here too.
      for (final key in dedupeKeys) {
        _dedupeCache.remove(key);
      }
      log('GrowthBookTrackingPlugin: failed to send events: '
          '${describeRequestError(e)}');
    }
  }
}
