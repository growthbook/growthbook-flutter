import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Plugins/growth_book_plugin.dart';

/// A built-in GrowthBook plugin that batches experiment and feature evaluation
/// events and POSTs them to the GrowthBook ingest endpoint.
///
/// **Wire contract**
/// - Endpoint:  POST `{ingestorHost}/track`
/// - Default host: `https://us1.gb-ingest.com`
/// - Body: `{ "client_key": "...", "events": [...] }`
///
/// **Batch defaults**
/// - batchSize: 100 events
/// - batchTimeout: 10 seconds
///
/// If initialized with an empty `clientKey` the plugin degrades to a no-op.
class GrowthBookTrackingPlugin extends GrowthBookPlugin {
  GrowthBookTrackingPlugin({
    String ingestorHost = defaultIngestorHost,
    int batchSize = defaultBatchSize,
    Duration batchTimeout = defaultBatchTimeout,
    Dio? dio,
  })  : _ingestorHost = ingestorHost,
        _batchSize = batchSize,
        _batchTimeout = batchTimeout,
        _dio = dio ?? Dio();

  static const String defaultIngestorHost = 'https://us1.gb-ingest.com';
  static const int defaultBatchSize = 100;
  static const Duration defaultBatchTimeout = Duration(seconds: 10);

  static const String _sdkVersion = '1.0.0';

  final String _ingestorHost;
  final int _batchSize;
  final Duration _batchTimeout;
  final Dio _dio;

  String _clientKey = '';
  bool _isInitialized = false;

  final List<GBIngestEvent> _eventQueue = [];
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
  void onExperimentViewed(GBExperiment experiment, GBExperimentResult result) {
    if (!_isInitialized) return;
    _enqueue(GBExperimentViewedEvent.from(experiment, result));
  }

  @override
  void onFeatureEvaluated(String featureKey, GBFeatureResult result) {
    if (!_isInitialized) return;
    _enqueue(GBFeatureEvaluatedEvent.from(featureKey, result));
  }

  /// Stops the flush timer and sends all buffered events before returning.
  @override
  void close() {
    _stopTimer();
    _flushSync();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _enqueue(GBIngestEvent event) {
    _eventQueue.add(event);
    if (_eventQueue.length >= _batchSize) {
      _flushAsync();
    }
  }

  void _startTimer() {
    _flushTimer = Timer.periodic(_batchTimeout, (_) => _flushAsync());
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

  void _flushSync() {
    final events = _drainQueue();
    if (events.isEmpty) return;
    // Best-effort synchronous post — fire and forget since Dart has no
    // blocking primitives on the main isolate.
    _post(events);
  }

  List<GBIngestEvent> _drainQueue() {
    final events = List<GBIngestEvent>.from(_eventQueue);
    _eventQueue.clear();
    return events;
  }

  Future<void> _post(List<GBIngestEvent> events) async {
    final payload = GBIngestPayload(clientKey: _clientKey, events: events);
    final url = '$_ingestorHost/track';

    try {
      await _dio.post<void>(
        url,
        data: jsonEncode(payload.toJson()),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'growthbook-flutter-sdk/$_sdkVersion',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      log('GrowthBookTrackingPlugin: failed to send events: $e');
    }
  }
}
