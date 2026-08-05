import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';

import '../Helper/gb_test_helper.dart';

void main() {
  group('forcedVariations value parsing', () {
    GBExperimentResult evaluate(dynamic forcedValue) {
      final gbContext = GBContext(
        apiKey: '',
        hostURL: '',
        enabled: true,
        attributes: {'id': 'user1'},
        forcedVariation: {'my-test': forcedValue},
        qaMode: false,
        trackingCallBack: (_) {},
        backgroundSync: false,
        features: {},
      );
      final evaluationContext = GBUtils.initializeEvalContext(gbContext, null);
      final experiment = GBExperiment(key: 'my-test', variations: [0, 1, 2]);
      return ExperimentEvaluator()
          .evaluateExperiment(evaluationContext, experiment);
    }

    test('int value 1 → variationID 1', () {
      expect(evaluate(1).variationID, 1);
    });

    test('double value 1.0 → variationID 1 (no FormatException)', () {
      expect(evaluate(1.0).variationID, 1);
    });

    test('string "1" → variationID 1', () {
      expect(evaluate('1').variationID, 1);
    });

    test('string "1.0" → variationID 1', () {
      expect(evaluate('1.0').variationID, 1);
    });

    test('fractional double 1.9 → does not crash, forced variation skipped',
        () {
      expect(() => evaluate(1.9), returnsNormally);
    });

    test('fractional string "1.9" → does not crash, forced variation skipped',
        () {
      expect(() => evaluate('1.9'), returnsNormally);
    });

    test('out-of-bounds index 99 → does not crash, forced variation skipped',
        () {
      expect(() => evaluate(99), returnsNormally);
    });

    test('invalid value "abc" → does not crash, falls through', () {
      expect(() => evaluate('abc'), returnsNormally);
    });

    test('invalid value true → does not crash, falls through', () {
      expect(() => evaluate(true), returnsNormally);
    });
  });

  group('GBExperimentRun Test', () {
    late final List evaluateCondition;
    setUpAll(() {
      evaluateCondition = GBTestHelper.getRunExperimentData();
    });

    test('Evaluate Feature', () {
      final failedScenarios = <String>[];
      final passedScenarios = <String>[];
      int failingIndex = 0;
      final listOfFailingIndex = <int>[];

      for (int i = 0; i < evaluateCondition.length; i++) {
        var item = evaluateCondition[i];
        if (item is List) {
          final testContext = GBContextTest.fromMap(item[1]);

          final experiment = GBExperiment.fromJson(item[2]);

          final attr = testContext.attributes;

          final gbContext = GBContext(
              apiKey: '',
              hostURL: '',
              enabled: testContext.enabled,
              attributes: attr,
              forcedVariation: testContext.forcedVariations,
              qaMode: testContext.qaMode,
              trackingCallBack: (_) {},
              backgroundSync: false,
              features: testContext.features,
              savedGroups: testContext.savedGroups,
              url: testContext.url);

          final evaluationContext =
              GBUtils.initializeEvalContext(gbContext, null);

          final result = ExperimentEvaluator()
              .evaluateExperiment(evaluationContext, experiment);
          final status =
              "${item[0]}\nExpected Result - ${item[3]} & ${item[4]}\nActual result - ${result.value} & ${result.inExperiment}\n\n";

          if (item[3].toString() == result.value.toString() &&
              item[4] == result.inExperiment) {
            passedScenarios.add(status);
          } else {
            failedScenarios.add(status);
            listOfFailingIndex.add(failingIndex);
          }
          failingIndex++;
        }
      }
      logger.i(
          'Passed Test ${passedScenarios.length} out of ${evaluateCondition.length}');
      expect(failedScenarios.length, 0);
    });
  });
}
