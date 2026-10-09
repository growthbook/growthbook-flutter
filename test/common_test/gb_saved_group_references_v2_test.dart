import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

import '../Helper/gb_test_helper.dart';

/// The `savedGroupReferencesV2` section of the shared spec corpus.
///
/// It nests its own `evalCondition`, `feature` and `run` cases, which the
/// top-level runners never read. Each case is its own test, so a failure names
/// the scenario.
///
/// The `feature` and `run` cases are not redundant with the condition-level
/// ones: they reach the evaluator through a rule or an experiment, so they also
/// pin that `savedGroups` is passed along that path.
void main() {
  group('savedGroupReferencesV2 - evalCondition', () {
    for (final item
        in GBTestHelper.getSavedGroupReferencesV2EvalConditionData()) {
      test(item[0], () {
        final result = GBConditionEvaluator().isEvalCondition(
          item[2],
          item[1],
          item.length == 5 ? item[4] : {},
        );
        expect(result, item[3]);
      });
    }
  });

  group('savedGroupReferencesV2 - feature', () {
    for (final item in GBTestHelper.getSavedGroupReferencesV2FeatureData()) {
      test(item[0], () {
        final testContext = GBContextTest.fromMap(item[1]);
        final testData = GBFeaturesTest.fromMap(item[1]);

        final gbContext = GBContext(
          encryptionKey: null,
          enabled: true,
          qaMode: false,
          attributes: testData.attributes,
          forcedVariation: testData.forcedVariations,
          trackingCallBack: (_) {},
          backgroundSync: false,
          savedGroups: testContext.savedGroups,
        );
        if (testData.features != null) {
          gbContext.features = testData.features!;
        }

        final evaluationContext =
            GBUtils.initializeEvalContext(gbContext, null);
        final result =
            FeatureEvaluator().evaluateFeature(evaluationContext, item[2]);
        final expected = GBFeatureResultTest.fromMap(item[3]);

        expect(result.value.toString(), expected.value.toString());
        expect(result.on, expected.on);
        expect(result.off, expected.off);
        expect(result.source?.name, expected.source);
        expect(result.ruleId, expected.ruleId);
        expect(result.experiment?.key, expected.experiment?.key);
        expect(result.experimentResult?.variationID,
            expected.experimentResult?.variationId);
      });
    }
  });

  group('savedGroupReferencesV2 - run', () {
    for (final item in GBTestHelper.getSavedGroupReferencesV2RunData()) {
      test(item[0], () {
        final testContext = GBContextTest.fromMap(item[1]);

        final gbContext = GBContext(
          apiKey: '',
          hostURL: '',
          enabled: testContext.enabled,
          attributes: testContext.attributes,
          forcedVariation: testContext.forcedVariations,
          qaMode: testContext.qaMode,
          trackingCallBack: (_) {},
          backgroundSync: false,
          features: testContext.features,
          savedGroups: testContext.savedGroups,
          url: testContext.url,
        );

        final evaluationContext =
            GBUtils.initializeEvalContext(gbContext, null);
        final result = ExperimentEvaluator().evaluateExperiment(
            evaluationContext, GBExperiment.fromJson(item[2]));

        expect(result.value.toString(), item[3].toString());
        expect(result.inExperiment, item[4]);
      });
    }
  });
}
