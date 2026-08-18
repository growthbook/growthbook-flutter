import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/network_mock.dart';
import '../mocks/network_view_model_mock.dart';

/// Coverage for the TTL / stale-while-revalidate behaviour.
///
/// Two distinct contracts are pinned here:
///
/// 1. [FeatureViewModel.fetchFeatures] serves from cache inside the TTL window
///    and goes back to the network once it expires.
/// 2. Only [GrowthBookSDK.feature] opts into the background refresh via
///    `_triggerBackgroundRefreshIfNeeded`. [GrowthBookSDK.evalFeature] — and
///    therefore [GrowthBookSDK.isOn], which delegates to it — deliberately
///    does **not** refresh: it is reached from inside feature evaluation and
///    fetching there would re-enter the evaluation path. The last group locks
///    that in so the cycle cannot be reintroduced by accident.
void main() {
  group('TTL & Caching', () {
    late FeatureViewModel featureViewModel;
    late DataSourceMock dataSourceMock;
    late GBContext context;
    const testApiKey = '<SOME KEY>';
    const testHostURL = '<HOST URL>';
    const attr = <String, String>{};

    setUp(() async {
      // Every case builds its own SDK against the same api key, so the shared
      // on-disk cache has to start empty — otherwise a previous case's payload
      // satisfies the read and suppresses the network call under test.
      await CachingManager().clearCache();
      context = GBContext(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        enabled: true,
        forcedVariation: {},
        qaMode: false,
        trackingCallBack: (_) {},
      );
      dataSourceMock = DataSourceMock();
    });

    tearDown(() async {
      await CachingManager().clearCache();
    });

    test(
      'fetchFeatures serves from cache inside the TTL window and refetches after it expires',
      () async {
        const ttlSeconds = 2;

        featureViewModel = FeatureViewModel(
          encryptionKey: testApiKey,
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const MockNetworkClient(),
            context: context,
          ),
          ttlSeconds: ttlSeconds,
        );

        final url = context.getFeaturesURL();

        await featureViewModel.fetchFeatures(url);
        expect(dataSourceMock.isSuccess, isTrue);
        expect(dataSourceMock.counterNetworkCall, 1);

        // Inside the window: the cache answers, no second request.
        await featureViewModel.fetchFeatures(url);
        expect(dataSourceMock.counterNetworkCall, 1);

        await Future<void>.delayed(
          const Duration(seconds: ttlSeconds, milliseconds: 100),
        );

        // Window elapsed: back to the network.
        await featureViewModel.fetchFeatures(url);
        expect(dataSourceMock.counterNetworkCall, 2);
      },
    );

    test('feature() triggers a background refresh once the TTL has expired',
        () async {
      var refreshCallCount = 0;
      const ttlSeconds = 1;

      final sdk = await GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        client: const MockNetworkClient(),
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
        ttlSeconds: ttlSeconds,
      ).setRefreshHandlerV2((isSuccess, _) {
        if (isSuccess) refreshCallCount++;
      }).initialize();

      expect(refreshCallCount, 1, reason: 'initialize() performs one fetch');

      // Still inside the TTL window — no extra fetch.
      sdk.feature('onboarding');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(refreshCallCount, 1);

      await Future<void>.delayed(
        const Duration(seconds: ttlSeconds, milliseconds: 100),
      );

      // Expired — the next feature() call kicks off a fire-and-forget refresh.
      sdk.feature('onboarding');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(refreshCallCount, 2);
    });

    group('evaluation entry points that must NOT refresh', () {
      /// Builds an SDK whose TTL has already lapsed, so any refresh-on-read
      /// would be observable through the refresh handler.
      Future<GrowthBookSDK> buildExpiredSdk(void Function() onRefresh) async {
        const ttlSeconds = 1;
        final sdk = await GBSDKBuilderApp(
          apiKey: testApiKey,
          hostURL: testHostURL,
          attributes: attr,
          client: const MockNetworkClient(),
          growthBookTrackingCallBack: (_) {},
          backgroundSync: false,
          ttlSeconds: ttlSeconds,
        ).setRefreshHandlerV2((isSuccess, _) {
          if (isSuccess) onRefresh();
        }).initialize();

        await Future<void>.delayed(
          const Duration(seconds: ttlSeconds, milliseconds: 100),
        );
        return sdk;
      }

      test('evalFeature() does not refresh after the TTL expires', () async {
        var refreshCallCount = 0;
        final sdk = await buildExpiredSdk(() => refreshCallCount++);
        expect(refreshCallCount, 1, reason: 'only the initialize() fetch');

        sdk.evalFeature('onboarding');
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(refreshCallCount, 1,
            reason: 'evalFeature must not re-enter the fetch path');
      });

      test('isOn() does not refresh after the TTL expires', () async {
        var refreshCallCount = 0;
        final sdk = await buildExpiredSdk(() => refreshCallCount++);
        expect(refreshCallCount, 1, reason: 'only the initialize() fetch');

        expect(sdk.isOn('onboarding'), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(refreshCallCount, 1,
            reason: 'isOn delegates to evalFeature and inherits its contract');
      });
    });
  });
}
