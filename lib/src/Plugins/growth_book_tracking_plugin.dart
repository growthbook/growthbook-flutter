import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Configuration for [GrowthBookTrackingPlugin].
class GrowthBookTrackingPluginConfig {
  const GrowthBookTrackingPluginConfig({
    this.ingestorHost = defaultIngestorHost,
    this.batchSize = defaultBatchSize,
    this.batchTimeout = defaultBatchTimeout,
  });

  static const String defaultIngestorHost = 'https://us1.gb-ingest.com';
  static const int defaultBatchSize = 100;
  static const Duration defaultBatchTimeout = Duration(seconds: 10);

  final String ingestorHost;
  final int batchSize;
  final Duration batchTimeout;
}

/// A built-in GrowthBook plugin that batches experiment and feature evaluation
/// events and POSTs them to the GrowthBook ingest endpoint.
///
/// **Wire contract**
/// - Endpoint:  POST `{config.ingestorHost}/track?client_key={clientKey}`
/// - Body: `[{ "event_name": "...", "properties": {...}, "attributes": {...} }]`
/// - Headers: `Content-Type: application/json`, `User-Agent: growthbook-flutter-sdk/{version}`
///
/// If initialized with an empty `clientKey` the plugin degrades to a no-op.
class GrowthBookTrackingPlugin extends GrowthBookPlugin {
  GrowthBookTrackingPlugin({
    GrowthBookTrackingPluginConfig config = const GrowthBookTrackingPluginConfig(),
    Dio? dio,
  })  : _config = config,
        _dio = dio ?? Dio();

  static const String _sdkVersion = '4.2.4'; // x-release-please-version

  final GrowthBookTrackingPluginConfig _config;
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
  void onExperimentViewed(
    GBExperiment experiment,
    GBExperimentResult result,
    Map<String, dynamic>? attributes,
  ) {
    if (!_isInitialized) return;
    _enqueue(GBExperimentViewedEvent.from(experiment, result, _mergedAttributes(attributes)));
  }

  @override
  void onFeatureEvaluated(
    String featureKey,
    GBFeatureResult result,
    Map<String, dynamic>? attributes,
  ) {
    if (!_isInitialized) return;
    _enqueue(GBFeatureEvaluatedEvent.from(featureKey, result, _mergedAttributes(attributes)));
  }

  static Map<String, dynamic> _mergedAttributes(Map<String, dynamic>? userAttributes) {
    return {
      'sdk_language': 'dart',
      'sdk_version': _sdkVersion,
      ...?userAttributes,
    };
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

  void _flushSync() {
    final events = _drainQueue();
    if (events.isEmpty) return;
    _post(events);
  }

  List<GBIngestEvent> _drainQueue() {
    final events = List<GBIngestEvent>.from(_eventQueue);
    _eventQueue.clear();
    return events;
  }

  Future<void> _post(List<GBIngestEvent> events) async {
    final url = '${_config.ingestorHost}/track?client_key=$_clientKey';

    try {
      await _dio.post<void>(
        url,
        data: jsonEncode(events.map((e) => e.toJson()).toList()),
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
