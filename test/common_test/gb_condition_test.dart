import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Utils/utils.dart';
import 'package:growthbook_sdk_flutter/src/Evaluator/condition_evaluator.dart';

import '../Helper/gb_test_helper.dart';

void main() {
  group('Condition test', () {
    List evaluateCondition;
    evaluateCondition = GBTestHelper.getEvalConditionData();

    test('Test conditions', () {
      /// Counter for getting index of failing tests.
      int index = 0;
      final failedIndex = <int>[];
      final failedScenarios = <String>[];
      final passedScenarios = <String>[];
      for (final item in evaluateCondition) {
        if (item is List) {
          final localItem = item;
          final evaluator = GBConditionEvaluator();
          final result =
              evaluator.evaluateCondition(localItem[2], localItem[1]);
          final status = "${localItem[0]}\nExpected Result - ${localItem[3]}\nActual result - $result\n\n";
          if (localItem[3].toString() == result.toString()) {
            passedScenarios.add(status);
          } else {
            failedScenarios.add(status);
            failedIndex.add(index);
          }
        }
        index++;
      }
      expect(failedScenarios.length, 0);
      customLogger(
          'Passed Test ${passedScenarios.length} out of ${evaluateCondition.length}');
    });
  });
}
