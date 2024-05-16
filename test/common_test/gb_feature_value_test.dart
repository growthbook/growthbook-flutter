import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

import '../Helper/gb_test_helper.dart';
import '../mocks/network_mock.dart';

void main() {
  group('Feature Evaluator', () {
    late final List evaluateCondition;
    setUpAll(() {
      evaluateCondition = GBTestHelper.getFeatureData();
    });
    test('Test Feature', () {
      /// Counter for getting index of failing tests.
      int index = 0;
      final failedIndex = <int>[];
      final failedScenarios = <String>[];
      final passedScenarios = <String>[];

      for (final item in evaluateCondition) {
        final testData = GBFeaturesTest.fromMap(item[1]);

        final gbContext = GBContext(
          encryptionKey: null,
          enabled: true,
          qaMode: false,
          attributes: testData.attributes,
          forcedVariation: testData.forcedVariations,
          trackingCallBack: (_, __) {},
          backgroundSync: false,
        );
        if (testData.features != null) {
          gbContext.features = testData.features!;
        }

        final result =
            FeatureEvaluator(attributeOverrides: {}, context: gbContext, featureKey: item[2]).evaluateFeature();
        final expectedResult = GBFeatureResultTest.fromMap(item[3]);

        final status =
            "${item[0]}\nValue expected- ${expectedResult.value}\nValue actual- ${result.value}\nOn  expected -${expectedResult.on}\nOn  actual -${result.on}\nOff  expected -${expectedResult.off}\nOff actual -${result.off}\nSource  expected -${expectedResult.source}\nSource  actual -${result.source?.name.toString()}\nExperiment  expected -${expectedResult.experiment?.key.toString()}\nExperiment  actual -${result.experiment?.key}\nExperimentResult expected -${expectedResult.experimentResult?.variationId.toString()}\nExperimentResult  actual -${result.experimentResult?.variationID.toString()}\n\n";
        if (result.value.toString() == expectedResult.value.toString() &&
            result.on.toString() == expectedResult.on.toString() &&
            result.off.toString() == expectedResult.off.toString() &&
            result.source?.name.toString() == expectedResult.source &&
            result.experiment?.key == expectedResult.experiment?.key &&
            result.experimentResult?.variationID == expectedResult.experimentResult?.variationId) {
          passedScenarios.add(status);
        } else {
          failedScenarios.add(status);
          failedIndex.add(index);
        }
        index++;
      }
      customLogger('Passed Test ${passedScenarios.length} out of ${evaluateCondition.length}');
      expect(failedScenarios.length, 0);
    });

    test('Whether featureUsageCallback is called', () async {
      const expectedNumberOfOnFeatureUsageCalls = 1;
      int actualNumberOfOnFeatureUsageCalls = 0;

      const testApiKey = '<API_KEY>';
      const attr = <String, String>{};
      const testHostURL = 'https://example.growthbook.io/';

      final gbBuilder = GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attr,
        client: const MockNetworkClient(),
        growthBookTrackingCallBack: (exp, res) {},
        backgroundSync: false,
      );

      gbBuilder.setFeatureUsageCallback((_, __) {
        actualNumberOfOnFeatureUsageCalls++;
      });

      final sdk = await gbBuilder.initialize();

      for (final item in evaluateCondition) {
        if (item is List<dynamic>) {
          sdk.feature(item[2]);
          break;
        }
      }

      expect(expectedNumberOfOnFeatureUsageCalls, actualNumberOfOnFeatureUsageCalls);
    });

    test('Whether featureUsageCallback is called on context level', () {
      const expectedNumberOfOnFeatureUsageCalls = 1;
      var actualNumberOfOnFeatureUsageCalls = 0;

      for (final item in evaluateCondition) {
        if (item is List<dynamic>) {
          final testData = GBFeaturesTest.fromMap(item[1]);
          final attributes = Map<String, dynamic>.from(testData.attributes ?? {});

          final gbContext = GBContext(
            apiKey: '',
            hostURL: '',
            enabled: true,
            attributes: attributes,
            forcedVariation: {},
            qaMode: false,
            trackingCallBack: (_, __) {},
            featureUsageCallback: (_, __) {
              actualNumberOfOnFeatureUsageCalls++;
            },
            encryptionKey: '',
          );
          if (testData.features != null) {
            gbContext.features = testData.features!;
          }

          if (testData.forcedVariations != null) {
            gbContext.forcedVariation = testData.forcedVariations!;
          }

          final evaluator = FeatureEvaluator(context: gbContext, featureKey: item[2], attributeOverrides: attributes);
          evaluator.evaluateFeature();

          expect(expectedNumberOfOnFeatureUsageCalls, actualNumberOfOnFeatureUsageCalls);
          break;
        }
      }
    });
  });
}
