import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_variation_meta.dart';

import '../mocks/network_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Initialization', () {
    const testApiKey = '<API_KEY>';
    const attr = <String, String>{};
    const testHostURL = 'https://example.growthbook.io';
    const client = MockNetworkClient();

    CacheStorage manager = FileCacheStorage();

    var isRefreshed = false;
    const channel = MethodChannel('plugins.flutter.io/path_provider');

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationSupportDirectory') {
          return '/tmp'; 
        }
        return null;
      });
    });

    tearDownAll(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test("- default", () async {
      final sdk = await GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        client: client,
        growthBookTrackingCallBack: (trackData) {},
        backgroundSync: false,
      )
          .setRefreshHandler((refreshHandler) => refreshHandler = isRefreshed)
          .initialize();

      /// Test API key
      expect(sdk.context.apiKey, testApiKey);

      /// Feature mode
      expect(sdk.context.enabled, true);

      /// Test HostUrl
      expect(sdk.context.hostURL, testHostURL);

      /// Test qaMode
      expect(sdk.context.qaMode, false);

      /// Test passed attr.
      expect(sdk.context.attributes, attr);

      manager.clearCache();
    });

    test('- qa mode', () async {
      const variations = <String, int>{};

      final sdk = await GBSDKBuilderApp(
        apiKey: testApiKey,
        qaMode: true,
        client: client,
        forcedVariations: variations,
        hostURL: testHostURL,
        attributes: attr,
        growthBookTrackingCallBack: (trackData) {},
        backgroundSync: false,
      ).setRefreshHandler((refreshHandler) {}).initialize();
      expect(sdk.context.enabled, true);
      expect(sdk.context.qaMode, true);

      manager.clearCache();
    });

    test(
        '- with initialization without throwing assertion error for wrong host url',
        () async {
      final sdkInstance = GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        client: client,
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
      );
      expect(sdkInstance, isNotNull);
      manager.clearCache();
    });

    test('- with network client', () async {
      GrowthBookSDK sdk = await GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        client: client,
        growthBookTrackingCallBack: (trackData) {},
        backgroundSync: false,
      ).setRefreshHandler((refreshHandler) => refreshHandler = isRefreshed).initialize();
      final featureValue = sdk.feature('some-feature');
      expect(featureValue.source, GBFeatureSource.unknownFeature);
      final result = sdk.run(GBExperiment(key: "some-feature"));
      expect(result.variationID, 0);
      manager.clearCache();
    });

    test(
      '- with failed network client',
      () async {
        GrowthBookSDK sdk = await GBSDKBuilderApp(
          apiKey: testApiKey,
          hostURL: testHostURL,
          attributes: attr,
          client: const MockNetworkClient(error: true),
          growthBookTrackingCallBack: (trackData) {},
          gbFeatures: {'some-feature': GBFeature(defaultValue: true)},
          backgroundSync: false,
        ).setRefreshHandler((refreshHandler) {}).initialize();
        final featureValue = sdk.feature('some-feature');
        expect(featureValue.value ?? true, true);
        final result = sdk.run(GBExperiment(key: "some-feature"));
        expect(result.variationID, 0);
        manager.clearCache();
      },
    );

    test('- testEncrypt', () async {
      final sdkInstance = await GBSDKBuilderApp(
        hostURL: testHostURL,
        apiKey: testApiKey,
        growthBookTrackingCallBack: (trackData) {},
        attributes: attr,
        backgroundSync: false,
      ).setRefreshHandler((refreshHandler) {}).initialize();

      const encryptedFeatures =
          "vMSg2Bj/IurObDsWVmvkUg==.L6qtQkIzKDoE2Dix6IAKDcVel8PHUnzJ7JjmLjFZFQDqidRIoCxKmvxvUj2kTuHFTQ3/NJ3D6XhxhXXv2+dsXpw5woQf0eAgqrcxHrbtFORs18tRXRZza7zqgzwvcznx";
      const expectedResult =
          '{"testfeature1":{"defaultValue":true,"rules":[{"condition":{"id":"1234"},"force":false}]}}';

      sdkInstance.setEncryptedFeatures(
        encryptedFeatures,
        "Ns04T5n9+59rl2x3SlNHtQ==",
      );

      final dataExpectedResult = utf8.encode(expectedResult);
      final features =
          json.decode(utf8.decode(dataExpectedResult)) as Map<String, dynamic>;

      expect(
        sdkInstance.features["testfeature1"]?.rules?[0].condition,
        equals(features["testfeature1"]?["rules"]?[0]["condition"]),
      );
      expect(
        sdkInstance.features["testfeature1"]?.rules?[0].force,
        equals(features["testfeature1"]?["rules"]?[0]["force"]),
      );
      manager.clearCache();
    });
    test(
      '- onInitializationFailure callback test',
      () async {
        GBError? error;

        await GBSDKBuilderApp(
          apiKey: testApiKey,
          hostURL: testHostURL,
          attributes: attr,
          client: const MockNetworkClient(error: true),
          growthBookTrackingCallBack: (trackData) {},
          gbFeatures: {'some-feature': GBFeature(defaultValue: true)},
          onInitializationFailure: (e) => error = e,
          backgroundSync: false,
        )
            .setRefreshHandler((refreshHandler) => refreshHandler = isRefreshed)
            .initialize();

        expect(error != null, true);
        expect(error?.error is DioException, true);
        expect(error?.stackTrace != null, true);
        manager.clearCache();
      },
    );
    test('- testTrackingCallback', () async {
      int countTrackingCallback = 0;

      final sdkInstance = await GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        growthBookTrackingCallBack: (trackData) {
          countTrackingCallback += 1;
        },
        refreshHandler: null,
        backgroundSync: false,
      )
          .setRefreshHandler((refreshHandler) => refreshHandler = isRefreshed)
          .initialize();

      sdkInstance.context.features = {
        'feature 1': GBFeature(defaultValue: true),
        'feature 2': GBFeature(defaultValue: false),
        'feature 3': GBFeature(
          defaultValue: true,
          rules: [
            GBFeatureRule(
              id: 'rule 1',
              force: 'force',
              tracks: [
                GBTrack(
                  experiment: GBExperiment(key: 'testExperimentKey'),
                  result: GBExperimentResult(key: 'testExperimentResultKey', inExperiment: true),
                ),
              ],
            ),
          ],
        ),
      };

      sdkInstance.evalFeature('feature 1');
      sdkInstance.evalFeature('feature 2');
      sdkInstance.evalFeature('feature 3');

      expect(countTrackingCallback, equals(1));
    });
  });
}
