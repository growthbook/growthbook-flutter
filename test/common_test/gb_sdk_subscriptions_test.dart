import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/network_mock.dart';

void main() {
  group('GrowthBookSDK — subscriptions', () {
    const testApiKey = '<API_KEY>';
    const testHostURL = 'https://example.growthbook.io';
    const client = MockNetworkClient();
    final cachingManager = CachingManager();

    Future<GrowthBookSDK> buildSdk({Map<String, dynamic>? attributes}) async {
      return GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attributes ?? {'id': 'user-1'},
        client: client,
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
      ).initialize();
    }

    tearDown(() {
      cachingManager.clearCache();
    });

    // -------------------------------------------------------------------------
    // getAllResults
    // -------------------------------------------------------------------------
    group('getAllResults', () {
      test('returns empty map before any experiment runs', () async {
        final sdk = await buildSdk();
        expect(sdk.getAllResults(), isEmpty);
      });

      test('contains result after running an experiment', () async {
        final sdk = await buildSdk();
        sdk.run(GBExperiment(key: 'exp-a', variations: [0, 1]));
        expect(sdk.getAllResults(), contains('exp-a'));
      });

      test('accumulates results for multiple experiments', () async {
        final sdk = await buildSdk();
        sdk.run(GBExperiment(key: 'exp-a', variations: [0, 1]));
        sdk.run(GBExperiment(key: 'exp-b', variations: [0, 1]));
        final results = sdk.getAllResults();
        expect(results.length, 2);
        expect(results.containsKey('exp-a'), isTrue);
        expect(results.containsKey('exp-b'), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // subscribe / unsubscribe
    // -------------------------------------------------------------------------
    group('subscribe', () {
      test('callback is invoked when a new experiment is run', () async {
        final sdk = await buildSdk();
        GBExperiment? receivedExperiment;
        GBExperimentResult? receivedResult;

        sdk.subscribe((experiment, result) {
          receivedExperiment = experiment;
          receivedResult = result;
        });

        sdk.run(GBExperiment(key: 'exp-sub', variations: [0, 1]));

        expect(receivedExperiment, isNotNull);
        expect(receivedExperiment!.key, 'exp-sub');
        expect(receivedResult, isNotNull);
      });

      test('unsubscribe function stops future callbacks', () async {
        final sdk = await buildSdk();
        int callCount = 0;

        final unsubscribe = sdk.subscribe((_, __) => callCount++);

        sdk.run(GBExperiment(key: 'exp-1', variations: [0, 1]));
        expect(callCount, 1);

        unsubscribe();

        sdk.run(GBExperiment(key: 'exp-2', variations: [0, 1]));
        expect(callCount, 1);
      });

      test('multiple subscribers each receive the callback', () async {
        final sdk = await buildSdk();
        int count1 = 0;
        int count2 = 0;

        sdk.subscribe((_, __) => count1++);
        sdk.subscribe((_, __) => count2++);

        sdk.run(GBExperiment(key: 'exp-multi', variations: [0, 1]));

        expect(count1, 1);
        expect(count2, 1);
      });

      test('callback receives correct experiment key and result', () async {
        final sdk = await buildSdk();
        final captured = <Map<String, dynamic>>[];

        sdk.subscribe((experiment, result) {
          captured.add({'key': experiment.key, 'variationID': result.variationID});
        });

        sdk.run(GBExperiment(key: 'exp-check', variations: [0, 1]));

        expect(captured.length, 1);
        expect(captured.first['key'], 'exp-check');
      });
    });

    // -------------------------------------------------------------------------
    // fireSubscriptions — deduplication logic
    // -------------------------------------------------------------------------
    group('fireSubscriptions', () {
      test('does not re-fire when same experiment produces identical result', () async {
        final sdk = await buildSdk();
        int callCount = 0;
        sdk.subscribe((_, __) => callCount++);

        final experiment = GBExperiment(key: 'exp-dedup', variations: [0, 1]);
        sdk.run(experiment); // first run — fires (no previous assignment)
        sdk.run(experiment); // same result — must not fire again
        expect(callCount, 1);
      });

      test('fires again when forced variationID changes between runs', () async {
        final sdk = await buildSdk();
        int callCount = 0;
        sdk.subscribe((_, __) => callCount++);

        sdk.run(GBExperiment(key: 'exp-change', variations: [0, 1], force: 0));
        expect(callCount, 1);

        // force different variation → variationID changes → subscription fires
        sdk.run(GBExperiment(key: 'exp-change', variations: [0, 1], force: 1));
        expect(callCount, 2);
      });

      test('independent experiments each fire their own subscription event', () async {
        final sdk = await buildSdk();
        int callCount = 0;
        sdk.subscribe((_, __) => callCount++);

        sdk.run(GBExperiment(key: 'exp-x', variations: [0, 1]));
        sdk.run(GBExperiment(key: 'exp-y', variations: [0, 1]));
        expect(callCount, 2);
      });
    });

    // -------------------------------------------------------------------------
    // clearSubscriptions
    // -------------------------------------------------------------------------
    group('clearSubscriptions', () {
      test('removes all active subscriptions', () async {
        final sdk = await buildSdk();
        int callCount = 0;

        sdk.subscribe((_, __) => callCount++);
        sdk.subscribe((_, __) => callCount++);
        sdk.clearSubscriptions();

        sdk.run(GBExperiment(key: 'exp-clear', variations: [0, 1]));
        expect(callCount, 0);
      });

      test('subscriptions added after clear still work', () async {
        final sdk = await buildSdk();
        int callCount = 0;

        sdk.subscribe((_, __) => callCount++);
        sdk.clearSubscriptions();
        sdk.subscribe((_, __) => callCount++);

        sdk.run(GBExperiment(key: 'exp-after-clear', variations: [0, 1]));
        expect(callCount, 1);
      });
    });
  });
}
