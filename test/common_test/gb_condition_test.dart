import 'dart:convert';

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
        final evaluator = GBConditionEvaluator();
        final result = evaluator.evaluateCondition(item[2], item[1]);
        final status = "${item[0]}\nExpected Result - ${item[3]}\nActual result - $result\n\n";
        if (item[3].toString() == result.toString()) {
          passedScenarios.add(status);
        } else {
          failedScenarios.add(status);
          failedIndex.add(index);
        }
        index++;
      }
      expect(failedScenarios.length, 0);
      customLogger('Passed Test ${passedScenarios.length} out of ${evaluateCondition.length}');
    });

    test('Test valid condition obj', () {
      final evaluator = GBConditionEvaluator();

      expect(evaluator.evaluateCondition({}, []), false);

      expect(evaluator.isOperatorObject({}), false);

      expect(evaluator.getPath('test', 'key'), null);

      expect(evaluator.evalConditionValue(<String, dynamic>{}, null), false);

      expect(evaluator.evalOperatorCondition("\$lte", "abc", "abc"), true);

      expect(evaluator.evalOperatorCondition("\$gte", "abc", "abc"), true);

      expect(evaluator.evalOperatorCondition("\$vlt", "0.9.0", "0.10.0"), true);

      expect(evaluator.evalOperatorCondition("\$in", "abc", ["abc"]), true);

      expect(evaluator.evalOperatorCondition("\$nin", "abc", ["abc"]), false);
    });
  });

  test('Test condition fail attribute does not exist', () {
    const attributes = '''
      {"country":"IN"}
    ''';

    const condition = '''
      {"brand":"KZ"}
    ''';

    expect(
      GBConditionEvaluator().evaluateCondition(
        jsonDecode(attributes),
        jsonDecode(condition),
      ),
      false,
    );
  });

  test('Test condition does not exist attribute exist', () {
    const attributes = '''
      {"userId":"1199"}
    ''';

    const condition = '''
      {
        "userId": {
          "\$exists": false
        }
      }
    ''';

    expect(
      GBConditionEvaluator().evaluateCondition(
        jsonDecode(attributes),
        jsonDecode(condition),
      ),
      false,
    );
  });

  test('Test condition exist attribute exist', () {
    const attributes = '''
      {"userId":"1199"}
    ''';

    const condition = '''
      {
        "userId": {
          "\$exists": true
        }
      }
    ''';

    expect(
      GBConditionEvaluator().evaluateCondition(
        jsonDecode(attributes),
        jsonDecode(condition),
      ),
      true,
    );
  });

  test('Test condition exist attribute does not exist', () {
    const String attributes = '''
        {"user_id_not_exist":"1199"}
    ''';

    const String condition = '''
        {
          "userId": {
            "\$exists": true
          }
        }
    ''';

    expect(
      GBConditionEvaluator().evaluateCondition(
        jsonDecode(attributes),
        jsonDecode(condition),
      ),
      false,
    );
  });
}
