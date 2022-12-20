import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

import '../mocks/network_mock.dart';

void main() {
  group('SDK_BUILDER_TEST', () {
    const testApiKey = 'key_prod_284897d8a1c89689';
    const attr = <String, String>{};
    const testHostURL =
        'http://a2c0156b9af934bcaa8f539de1928e85-2035136552.ap-south-1.elb.amazonaws.com:3100/';

    test("testSDKInitializationDefault", () {
      var sdk = GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        growthBookTrackingCallBack: (experiment, experimentResult) {},
      ).initialize();

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
    });

    test('testSDKInitializationData', () {
      const variations = <String, int>{};
      bool fetched = false;
      final sdk = GBSDKBuilderApp(
              apiKey: testApiKey,
              hostURL: testHostURL,
              attributes: attr,
              growthBookTrackingCallBack: (exp, result) {})
          .setQAMode(true)
          .setForcedVariations(variations)
          .initialize()
        ..afterFetch = () {
          fetched = true;
        };
      sdk.afterFetch!();
      expect(sdk.context.enabled, true);
      expect(sdk.context.qaMode, true);
      expect(fetched, true);
    });

    test('testSDKFeatureData', () async {
      late GrowthBookSDK sdk;
      final client = MockNetworkClient();
      sdk = GBSDKBuilderApp(
              apiKey: testApiKey,
              hostURL: testHostURL,
              attributes: attr,
              growthBookTrackingCallBack: (exp, result) {})
          .setNetworkDispatcher(client)
          .initialize();
      final featureValue = sdk.feature('fwrfewrfe');
      expect(featureValue.source, GBFeatureSource.unknownFeature);
    });
  });
}
