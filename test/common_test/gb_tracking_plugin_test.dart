import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

import '../mocks/network_mock.dart';

// ---------------------------------------------------------------------------
// MockPlugin — records all plugin calls for integration assertions.
// ---------------------------------------------------------------------------

class MockPlugin extends GrowthBookPlugin {
  String? initializedWith;
  int experimentCallCount = 0;
  int featureCallCount = 0;
  bool closeCalled = false;

  @override
  void initialize(String clientKey) => initializedWith = clientKey;

  @override
  void onExperimentViewed(GBExperiment experiment, GBExperimentResult result,
          Map<String, dynamic>? attributes) =>
      experimentCallCount++;

  @override
  void onFeatureEvaluated(String featureKey, GBFeatureResult result,
          Map<String, dynamic>? attributes) =>
      featureCallCount++;

  @override
  void close() => closeCalled = true;
}

// ---------------------------------------------------------------------------
// MockHttpAdapter — intercepts Dio requests without real network calls.
// ---------------------------------------------------------------------------

typedef _ReqHandler = Future<ResponseBody> Function(RequestOptions options);

class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this.handler);

  final _ReqHandler handler;
  int requestCount = 0;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requestCount++;
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok() => ResponseBody.fromString('', 200);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _clientKey = 'sdk-test-key';
const _hostURL = 'https://host.com';

Future<GrowthBookSDK> _makeSDK({List<GrowthBookPlugin> plugins = const []}) {
  var builder = GBSDKBuilderApp(
    apiKey: _clientKey,
    hostURL: _hostURL,
    attributes: const {'id': 'user-1'},
    growthBookTrackingCallBack: (_) {},
    client: const MockNetworkClient(),
    backgroundSync: false,
    ttlSeconds: 60,
  );
  for (final p in plugins) {
    builder.addPlugin(p);
  }
  return builder.initialize();
}

GBExperiment _makeExp({double coverage = 1.0}) => GBExperiment(
      key: 'test-exp-${DateTime.now().microsecondsSinceEpoch}',
      variations: [0, 1],
      coverage: coverage,
    );

// ---------------------------------------------------------------------------
// Plugin integration tests
// ---------------------------------------------------------------------------

void main() {
  group('GrowthBookPlugin — integration', () {
    test('plugin receives initialize with clientKey', () async {
      final plugin = MockPlugin();
      await _makeSDK(plugins: [plugin]);
      expect(plugin.initializedWith, equals(_clientKey));
    });

    test('plugin.close called via dispose()', () async {
      final plugin = MockPlugin();
      final sdk = await _makeSDK(plugins: [plugin]);
      sdk.dispose();
      expect(plugin.closeCalled, isTrue);
    });

    test('plugin receives onExperimentViewed when inExperiment=true', () async {
      final plugin = MockPlugin();
      final sdk = await _makeSDK(plugins: [plugin]);
      sdk.run(_makeExp(coverage: 1.0));
      expect(plugin.experimentCallCount, equals(1));
    });

    test('plugin NOT called when user not in experiment', () async {
      final plugin = MockPlugin();
      final sdk = await _makeSDK(plugins: [plugin]);
      sdk.run(_makeExp(coverage: 0.0));
      expect(plugin.experimentCallCount, equals(0));
    });

    test('plugin receives onFeatureEvaluated from evalFeature()', () async {
      final plugin = MockPlugin();
      final sdk = await _makeSDK(plugins: [plugin]);
      sdk.evalFeature('flag-a');
      expect(plugin.featureCallCount, equals(1));
    });

    test('plugin receives onFeatureEvaluated from feature()', () async {
      final plugin = MockPlugin();
      final sdk = await _makeSDK(plugins: [plugin]);
      sdk.feature('flag-a');
      expect(plugin.featureCallCount, equals(1));
    });

    test('plugin receives onFeatureEvaluated for unknown feature', () async {
      final plugin = MockPlugin();
      final sdk = await _makeSDK(plugins: [plugin]);
      sdk.evalFeature('nonexistent');
      expect(plugin.featureCallCount, equals(1));
    });

    test('multiple plugins all receive events', () async {
      final p1 = MockPlugin();
      final p2 = MockPlugin();
      final sdk = await _makeSDK(plugins: [p1, p2]);
      sdk.evalFeature('flag-a');
      expect(p1.featureCallCount, equals(1));
      expect(p2.featureCallCount, equals(1));
    });

    test('multiple plugins all initialized', () async {
      final p1 = MockPlugin();
      final p2 = MockPlugin();
      await _makeSDK(plugins: [p1, p2]);
      expect(p1.initializedWith, equals(_clientKey));
      expect(p2.initializedWith, equals(_clientKey));
    });

    test('misbehaving plugin does not crash the SDK', () async {
      final sdk = await _makeSDK(plugins: [_CrashingPlugin()]);
      expect(() => sdk.evalFeature('flag'), returnsNormally);
      expect(() => sdk.run(_makeExp()), returnsNormally);
      expect(() => sdk.dispose(), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // GrowthBookTrackingPlugin unit tests
  // -------------------------------------------------------------------------

  group('GrowthBookTrackingPlugin', () {
    late _MockHttpAdapter adapter;
    late Dio dio;

    setUp(() {
      adapter = _MockHttpAdapter((_) async => _ok());
      dio = Dio()..httpClientAdapter = adapter;
    });

    GrowthBookTrackingPlugin makePlugin({
      int batchSize = GrowthBookTrackingPlugin.defaultBatchSize,
      Duration batchTimeout = const Duration(seconds: 60),
    }) =>
        GrowthBookTrackingPlugin(batchSize: batchSize, batchTimeout: batchTimeout, dio: dio);

    GBExperiment exp() => GBExperiment(key: 'test-exp', variations: [0, 1]);

    GBExperimentResult expResult() => GBExperimentResult(
          inExperiment: true,
          variationID: 1,
          key: '1',
          hashAttribute: 'id',
          hashValue: 'user-1',
        );

    // No-op without clientKey
    test('no-op with empty clientKey', () async {
      final plugin = makePlugin(batchSize: 1);
      plugin.initialize('');
      plugin.onExperimentViewed(exp(), expResult(), null);
      plugin.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(adapter.requestCount, equals(0));
    });

    // Batch size flush
    test('flushes when batch size is reached', () async {
      final completer = Completer<RequestOptions>();
      adapter = _MockHttpAdapter((options) async {
        if (!completer.isCompleted) completer.complete(options);
        return _ok();
      });
      dio.httpClientAdapter = adapter;

      final plugin = makePlugin(batchSize: 3);
      plugin.initialize('sdk-test');
      for (var i = 0; i < 3; i++) {
        plugin.onExperimentViewed(exp(), expResult(), null);
      }

      final req = await completer.future.timeout(const Duration(seconds: 3));
      expect(req.uri.queryParameters['client_key'], equals('sdk-test'));
      final events = jsonDecode(req.data as String) as List;
      expect(events.length, equals(3));
    });

    test('does not flush before batch size is reached', () async {
      final plugin = makePlugin(batchSize: 5);
      plugin.initialize('sdk-test');
      for (var i = 0; i < 4; i++) {
        plugin.onExperimentViewed(exp(), expResult(), null);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(adapter.requestCount, equals(0));
      plugin.close();
    });

    // Timer flush
    test('timer triggers flush', () async {
      final completer = Completer<void>();
      adapter = _MockHttpAdapter((_) async {
        if (!completer.isCompleted) completer.complete();
        return _ok();
      });
      dio.httpClientAdapter = adapter;

      final plugin = GrowthBookTrackingPlugin(
        batchTimeout: const Duration(milliseconds: 100),
        dio: dio,
      );
      plugin.initialize('sdk-test');
      plugin.onExperimentViewed(exp(), expResult(), null);

      await completer.future.timeout(const Duration(seconds: 3));
      expect(adapter.requestCount, greaterThan(0));
    });

    // close() flush
    test('close() sends remaining events', () async {
      final completer = Completer<void>();
      adapter = _MockHttpAdapter((_) async {
        if (!completer.isCompleted) completer.complete();
        return _ok();
      });
      dio.httpClientAdapter = adapter;

      final plugin = makePlugin(batchSize: 100);
      plugin.initialize('sdk-test');
      plugin.onExperimentViewed(exp(), expResult(), null);

      expect(adapter.requestCount, equals(0));
      plugin.close();

      await completer.future.timeout(const Duration(seconds: 3));
      expect(adapter.requestCount, equals(1));
    });

    test('close() with no events does not send request', () async {
      final plugin = makePlugin();
      plugin.initialize('sdk-test');
      plugin.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(adapter.requestCount, equals(0));
    });

    // Network failure
    test('network failure does not crash', () {
      adapter = _MockHttpAdapter((_) async => throw Exception('network error'));
      dio.httpClientAdapter = adapter;

      final plugin = makePlugin(batchSize: 100);
      plugin.initialize('sdk-test');
      plugin.onExperimentViewed(exp(), expResult(), null);
      expect(() => plugin.close(), returnsNormally);
    });

    // Request format
    test('posts to correct endpoint with correct headers', () async {
      final completer = Completer<RequestOptions>();
      adapter = _MockHttpAdapter((options) async {
        if (!completer.isCompleted) completer.complete(options);
        return _ok();
      });
      dio.httpClientAdapter = adapter;

      final plugin = GrowthBookTrackingPlugin(
        ingestorHost: GrowthBookTrackingPlugin.defaultIngestorHost,
        batchSize: 1,
        dio: dio,
      );
      plugin.initialize('sdk-test');
      plugin.onExperimentViewed(exp(), expResult(), null);

      final req = await completer.future.timeout(const Duration(seconds: 3));
      expect(req.uri.queryParameters['client_key'], equals('sdk-test'));
      expect(req.uri.path, equals('/track'));
      expect(req.method, equals('POST'));
      expect(req.headers['Content-Type'], equals('application/json'));
      expect(
        (req.headers['User-Agent'] as String)
            .startsWith('growthbook-flutter-sdk/'),
        isTrue,
      );
    });

    test('feature_evaluated event included in payload', () async {
      final completer = Completer<List<dynamic>>();
      adapter = _MockHttpAdapter((options) async {
        final events = jsonDecode(options.data as String) as List;
        if (!completer.isCompleted) completer.complete(events);
        return _ok();
      });
      dio.httpClientAdapter = adapter;

      final plugin = makePlugin(batchSize: 1);
      plugin.initialize('sdk-test');
      plugin.onFeatureEvaluated(
        'my-feature',
        GBFeatureResult(
          value: true,
          on: true,
          off: false,
          source: GBFeatureSource.defaultValue,
        ),
        null,
      );

      final events = await completer.future.timeout(const Duration(seconds: 3));
      expect(events.first['event_name'], equals('Feature Evaluated'));
      final props = events.first['properties'] as Map<String, dynamic>;
      expect(props['feature'], equals('my-feature'));
      final attrs = events.first['attributes'] as Map<String, dynamic>;
      expect(attrs['sdk_language'], equals('dart'));
      expect(attrs['sdk_version'], isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // GBSDKBuilderApp.addPlugin — builder chaining
  // -------------------------------------------------------------------------

  group('GBSDKBuilderApp — addPlugin', () {
    test('addPlugin returns builder for chaining', () {
      final plugin = MockPlugin();
      final builder = GBSDKBuilderApp(
        hostURL: _hostURL,
        apiKey: _clientKey,
        growthBookTrackingCallBack: (_) {},
      );
      expect(builder.addPlugin(plugin), same(builder));
    });
  });
}

// A plugin that throws on every call — verifies SDK error isolation.
class _CrashingPlugin extends GrowthBookPlugin {
  @override
  void initialize(String clientKey) => throw Exception('crash');
  @override
  void onExperimentViewed(GBExperiment e, GBExperimentResult r,
          Map<String, dynamic>? attributes) =>
      throw Exception('crash');
  @override
  void onFeatureEvaluated(String key, GBFeatureResult r,
          Map<String, dynamic>? attributes) =>
      throw Exception('crash');
  @override
  void close() => throw Exception('crash');
}
