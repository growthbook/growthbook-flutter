import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';

import '../mocks/network_mock.dart';

// ---------------------------------------------------------------------------
// MockPlugin — records all plugin calls for integration assertions.
// ---------------------------------------------------------------------------

class MockPlugin extends GrowthBookPlugin {
  String? initializedWith;
  int experimentCallCount = 0;
  int featureCallCount = 0;
  bool closeCalled = false;
  final List<String> experimentKeys = [];

  @override
  void initialize(String clientKey) => initializedWith = clientKey;

  @override
  void onExperimentViewed(GBExperiment experiment, GBExperimentResult result,
      Map<String, dynamic>? attributes) {
    experimentCallCount++;
    experimentKeys.add(experiment.key);
  }

  @override
  void onFeatureEvaluated(String featureKey, GBFeatureResult result,
          Map<String, dynamic>? attributes) =>
      featureCallCount++;

  @override
  Future<void> close() async => closeCalled = true;
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
      await sdk.dispose();
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
      int batchSize = GrowthBookTrackingPluginConfig.defaultBatchSize,
      Duration batchTimeout = const Duration(seconds: 60),
    }) =>
        GrowthBookTrackingPlugin(
          config: GrowthBookTrackingPluginConfig(
              batchSize: batchSize, batchTimeout: batchTimeout),
          dio: dio,
        );

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
        config: const GrowthBookTrackingPluginConfig(
            batchTimeout: Duration(milliseconds: 100)),
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
        config: const GrowthBookTrackingPluginConfig(batchSize: 1),
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
      final props = events.first['properties_json'] as Map<String, dynamic>;
      expect(props['feature'], equals('my-feature'));
      expect(events.first['sdk_language'], equals('dart'));
      expect(events.first['sdk_version'], isNotNull);
    });

    test('flush() sends buffered events and keeps the plugin recording',
        () async {
      final plugin = makePlugin(batchSize: 100);
      plugin.initialize('sdk-test');
      plugin.onExperimentViewed(exp(), expResult(), null);

      await plugin.flush();
      expect(adapter.requestCount, equals(1));

      // Still alive: a later event is buffered and delivered by the next flush.
      plugin.onExperimentViewed(exp(), expResult(), null);
      await plugin.flush();
      expect(adapter.requestCount, equals(2));
    });

    test('a buffered event keeps the attributes it was raised with', () async {
      final plugin = makePlugin(batchSize: 100);
      plugin.initialize('sdk-test');

      final attributes = <String, dynamic>{
        'user_id': 'old-user',
        'plan': {'tier': 'free'},
      };
      plugin.onExperimentViewed(exp(), expResult(), attributes);

      // The user changes before the batch goes out.
      attributes['user_id'] = 'new-user';
      (attributes['plan'] as Map<String, dynamic>)['tier'] = 'pro';
      await plugin.flush();

      final events = jsonDecode(adapter.lastRequest!.data as String) as List;
      expect(events.single['user_id'], equals('old-user'));
      expect(events.single['context_json']['plan']['tier'], equals('free'));
    });

    test('events raised after close() are dropped', () async {
      final plugin = makePlugin(batchSize: 1);
      plugin.initialize('sdk-test');
      await plugin.close();

      plugin.onExperimentViewed(exp(), expResult(), null);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(adapter.requestCount, equals(0));
    });
  });

  // -------------------------------------------------------------------------
  // Ingest payload parity with the Swift and Kotlin SDKs
  // -------------------------------------------------------------------------

  group('ingest payload parity', () {
    Map<String, dynamic> experimentPayload({
      GBExperimentResult? result,
      Map<String, dynamic> attributes = const {},
    }) =>
        GBExperimentViewedEvent.from(
          GBExperiment(key: 'my-exp', variations: [0, 1]),
          result ??
              GBExperimentResult(
                inExperiment: true,
                variationID: 1,
                key: 'treatment',
                hashAttribute: 'id',
                hashValue: 'user-1',
              ),
          attributes,
        ).toJson();

    Map<String, dynamic> featurePayload(GBFeatureResult result) =>
        GBFeatureEvaluatedEvent.from('my-feature', result, const {}).toJson();

    test('Experiment Viewed sends the variation key, not its index', () {
      final props =
          experimentPayload()['properties_json'] as Map<String, dynamic>;
      expect(props['variationId'], equals('treatment'));
      expect(props['experimentId'], equals('my-exp'));
    });

    test('Experiment Viewed carries the hash attribute and value', () {
      final props =
          experimentPayload()['properties_json'] as Map<String, dynamic>;
      expect(props['hashAttribute'], equals('id'));
      expect(props['hashValue'], equals('user-1'));
    });

    test('hash attribute and value are omitted when absent', () {
      final props = experimentPayload(
        result: GBExperimentResult(inExperiment: true, key: '0'),
      )['properties_json'] as Map<String, dynamic>;
      expect(props.containsKey('hashAttribute'), isFalse);
      expect(props.containsKey('hashValue'), isFalse);
    });

    test('identity attributes are promoted to top-level columns', () {
      final payload = experimentPayload(attributes: const {
        'user_id': 'u-1',
        'device_id': 'd-1',
        'page_id': 'p-1',
        'session_id': 's-1',
        'plan': 'pro',
      });

      expect(payload['user_id'], equals('u-1'));
      expect(payload['device_id'], equals('d-1'));
      expect(payload['page_id'], equals('p-1'));
      expect(payload['session_id'], equals('s-1'));
      expect(payload['context_json'], equals({'plan': 'pro'}));
    });

    test('device_id falls back to anonymous_id then id', () {
      expect(
        experimentPayload(attributes: const {
          'anonymous_id': 'a-1',
          'id': 'i-1'
        })['device_id'],
        equals('a-1'),
      );
      expect(
        experimentPayload(attributes: const {'id': 'i-1'})['device_id'],
        equals('i-1'),
      );
    });

    test('identity columns are null — not absent — when missing', () {
      final payload = experimentPayload();
      for (final key in ['user_id', 'device_id', 'page_id', 'session_id']) {
        expect(payload.containsKey(key), isTrue,
            reason: '$key must be present');
        expect(payload[key], isNull);
      }
    });

    test('a non-string identity attribute is sent as null', () {
      expect(experimentPayload(attributes: const {'user_id': 42})['user_id'],
          isNull);
    });

    test('campaign fields are omitted when absent and renamed when present',
        () {
      expect(experimentPayload().containsKey('utm_source'), isFalse);

      final payload = experimentPayload(attributes: const {
        'utmSource': 'newsletter',
        'utmMedium': 'email',
        'utmCampaign': 'spring',
        'utmTerm': 'flags',
        'utmContent': 'hero',
        'pageTitle': 'Home',
      });
      expect(payload['utm_source'], equals('newsletter'));
      expect(payload['utm_medium'], equals('email'));
      expect(payload['utm_campaign'], equals('spring'));
      expect(payload['utm_term'], equals('flags'));
      expect(payload['utm_content'], equals('hero'));
      expect(payload['page_title'], equals('Home'));
      // Promoted keys do not also appear in the context blob.
      expect(payload['context_json'], isEmpty);
    });

    test('envelope carries sdk metadata and an empty url', () {
      final payload = experimentPayload();
      expect(payload['event_name'], equals('Experiment Viewed'));
      expect(payload['sdk_language'], equals('dart'));
      expect(payload['sdk_version'], equals(gbSdkVersion));
      expect(payload['url'], equals(''));
    });

    test('sdk metadata is not mixed into the attributes', () {
      final payload = experimentPayload(attributes: const {'plan': 'pro'});
      expect(payload['context_json'], equals({'plan': 'pro'}));
    });

    test(r'Feature Evaluated normalizes ruleId to $default', () {
      final props = featurePayload(GBFeatureResult(
        value: true,
        source: GBFeatureSource.defaultValue,
        ruleId: 'ignored',
      ))['properties_json'] as Map<String, dynamic>;
      expect(props['ruleId'], equals(r'$default'));
    });

    test('Feature Evaluated sends an empty ruleId rather than null', () {
      final props = featurePayload(GBFeatureResult(
        value: true,
        source: GBFeatureSource.force,
        ruleId: null,
      ))['properties_json'] as Map<String, dynamic>;
      expect(props['ruleId'], equals(''));
    });

    test('Feature Evaluated carries the deciding variation key', () {
      final props = featurePayload(GBFeatureResult(
        value: 'b',
        source: GBFeatureSource.experiment,
        ruleId: 'rule-1',
        experimentResult:
            GBExperimentResult(inExperiment: true, key: 'treatment'),
      ))['properties_json'] as Map<String, dynamic>;

      expect(props['variationId'], equals('treatment'));
      expect(props['ruleId'], equals('rule-1'));
      expect(props['source'], equals('experiment'));
    });

    test('variationId is empty when no experiment decided the value', () {
      final props = featurePayload(GBFeatureResult(
        value: true,
        source: GBFeatureSource.force,
        ruleId: 'rule-1',
      ))['properties_json'] as Map<String, dynamic>;
      expect(props['variationId'], equals(''));
    });
  });

  // -------------------------------------------------------------------------
  // Exposures from feature flag rules — the regression behind issue #179
  // -------------------------------------------------------------------------

  group('experiment exposures from feature rules', () {
    test('an experiment run through a feature rule reaches the plugin', () {
      final f = _ExposureFixture();
      FeatureEvaluator().evaluateFeature(f.context, _ExposureFixture.flagKey);
      expect(f.plugin.experimentCallCount, equals(1));
    });

    test('the plugin receives the same exposure as the tracking callback', () {
      final f = _ExposureFixture();
      FeatureEvaluator().evaluateFeature(f.context, _ExposureFixture.flagKey);
      expect(f.trackedExperimentKeys, equals([f.experimentKey]));
      expect(f.plugin.experimentKeys, equals([f.experimentKey]));
    });

    test('a direct experiment exposure is reported exactly once', () {
      final f = _ExposureFixture();
      final experiment =
          GBExperiment(key: '${f.experimentKey}-direct', variations: [0, 1]);

      ExperimentEvaluator().evaluateExperiment(f.context, experiment);
      ExperimentEvaluator().evaluateExperiment(f.context, experiment);

      expect(f.plugin.experimentCallCount, equals(1));
    });

    test('another SDK instance does not suppress this one\'s exposure',
        () async {
      final experiment = _makeExp();

      // Same user, same experiment, no plugin: it must not use up the exposure.
      final other = await _makeSDK();
      other.run(experiment);
      await other.dispose();

      final plugin = MockPlugin();
      final sdk = await _makeSDK(plugins: [plugin]);
      sdk.run(experiment);

      expect(plugin.experimentCallCount, equals(1));
    });

    test('an attribute update does not report the exposure again', () async {
      final experiment = _makeExp();
      final plugin = MockPlugin();
      final sdk = await _makeSDK(plugins: [plugin]);

      sdk.run(experiment);
      sdk.setAttributes({'id': 'user-1'});
      sdk.run(experiment);

      expect(plugin.experimentCallCount, equals(1));
    });

    test('a closed registry stops reporting exposures', () async {
      final f = _ExposureFixture();
      await f.registry.close();

      FeatureEvaluator().evaluateFeature(f.context, _ExposureFixture.flagKey);
      expect(f.plugin.experimentCallCount, equals(0));
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

/// An evaluation context wired to a plugin registry, holding one feature whose
/// only rule is an experiment.
///
/// Every instance gets its own exposure history with its context; the fresh
/// experiment key and unit id just keep the fixtures apart in failure output.
class _ExposureFixture {
  _ExposureFixture() {
    final unique = _counter++;
    experimentKey = 'feature-exp-$unique';
    plugin = MockPlugin();
    registry = PluginRegistry([plugin]);

    final gbContext = GBContext(
      enabled: true,
      qaMode: false,
      attributes: {'id': 'user-$unique'},
      forcedVariation: const {},
      trackingCallBack: (data) =>
          trackedExperimentKeys.add(data.experiment.key),
      backgroundSync: false,
    );
    gbContext.features = {
      flagKey: GBFeature(
        defaultValue: 'control',
        rules: [
          GBFeatureRule(
            id: 'rule-1',
            key: experimentKey,
            variations: ['control', 'treatment'],
            // All traffic to the second variation, so the exposure is certain.
            weights: [0, 1],
            coverage: 1.0,
          ),
        ],
      ),
    };

    context = GBUtils.initializeEvalContext(gbContext, null,
        pluginRegistry: registry);
  }

  static const String flagKey = 'exp-flag';
  static int _counter = 0;

  late final String experimentKey;
  late final MockPlugin plugin;
  late final PluginRegistry registry;
  late final EvaluationContext context;
  final List<String> trackedExperimentKeys = [];
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
  void onFeatureEvaluated(
          String key, GBFeatureResult r, Map<String, dynamic>? attributes) =>
      throw Exception('crash');
  @override
  Future<void> close() => throw Exception('crash');
}
