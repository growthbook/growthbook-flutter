import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

import '../mocks/network_mock.dart';
import '../mocks/network_view_model_mock.dart';

void main() {
  group('TTL & Caching', () {
    late FeatureViewModel featureViewModel;
    late DataSourceMock dataSourceMock;
    late GBContext context;
    const testApiKey = '<SOME KEY>';
    const testHostURL = '<HOST URL>';
    const attr = <String, String>{};

    setUp(() {
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

    test(
      'fetchFeatures verification: should use cache within TTL window and refetch after expiration',
      () async {
        const int ttlSeconds = 2;

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

        expect(dataSourceMock.isSuccess, true);
        expect(dataSourceMock.counterNetworkCall, 1);

        await featureViewModel.fetchFeatures(url);

        expect(dataSourceMock.counterNetworkCall, 1);

        await Future.delayed(
            const Duration(seconds: ttlSeconds, milliseconds: 100));

        await featureViewModel.fetchFeatures(url);

        expect(dataSourceMock.counterNetworkCall, 2);
      },
    );

    test('evalFeature: triggers background refresh only after TTL expires',
        () async {
      int refreshCallCount = 0;
      const int ttlSeconds = 1;

      GrowthBookSDK sdk = await GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        client: const MockNetworkClient(),
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
        ttlSeconds: ttlSeconds,
      ).setRefreshHandler((isSuccess) {
        if (isSuccess) refreshCallCount++;
      }).initialize();

      expect(refreshCallCount, 1);

      sdk.evalFeature('onboarding');
      await Future.delayed(const Duration(milliseconds: 100));
      expect(refreshCallCount, 1);

      await Future.delayed(const Duration(seconds: 1, milliseconds: 100));

      sdk.evalFeature('onboarding');
      await Future.delayed(const Duration(milliseconds: 200));

      expect(refreshCallCount, 2);
    });

    test('feature: triggers background refresh only after TTL expires',
        () async {
      int refreshCallCount = 0;
      const int ttlSeconds = 1;

      GrowthBookSDK sdk = await GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        client: const MockNetworkClient(),
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
        ttlSeconds: ttlSeconds,
      ).setRefreshHandler((isSuccess) {
        if (isSuccess) refreshCallCount++;
      }).initialize();

      expect(refreshCallCount, 1);

      sdk.feature('onboarding');
      await Future.delayed(const Duration(milliseconds: 100));
      expect(refreshCallCount, 1);

      await Future.delayed(const Duration(seconds: 1, milliseconds: 100));

      sdk.feature('onboarding');
      await Future.delayed(const Duration(milliseconds: 200));

      expect(refreshCallCount, 2);
    });

    test('isOn: triggers background refresh only after TTL expires', () async {
      int refreshCallCount = 0;
      const int ttlSeconds = 1;

      GrowthBookSDK sdk = await GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        client: const MockNetworkClient(),
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
        ttlSeconds: ttlSeconds,
      ).setRefreshHandler((isSuccess) {
        if (isSuccess) refreshCallCount++;
      }).initialize();

      expect(refreshCallCount, 1);

      final initialValue = sdk.isOn('onboarding');
      expect(initialValue, true);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(refreshCallCount, 1);

      await Future.delayed(const Duration(seconds: 1, milliseconds: 100));

      final staleValue = sdk.isOn('onboarding');
      expect(staleValue, true);

      await Future.delayed(const Duration(milliseconds: 200));

      expect(refreshCallCount, 2);
    });
  });
}
