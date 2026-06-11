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
        final result = evaluator.isEvalCondition(item[2], item[1], item.length == 5 ? item[4] : {});
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

      expect(evaluator.isEvalCondition({}, [], {}), false);

      expect(evaluator.isOperatorObject({}), false);

      expect(evaluator.getPath('test', 'key'), null);

      expect(evaluator.isEvalConditionValue(<String, dynamic>{}, null, {}), false);

      expect(evaluator.evalOperatorCondition("\$lte", "abc", "abc", {}), true);

      expect(evaluator.evalOperatorCondition("\$gte", "abc", "abc", {}), true);

      expect(evaluator.evalOperatorCondition("\$vlt", "0.9.0", "0.10.0", {}), true);

      expect(evaluator.evalOperatorCondition("\$in", "abc", ["abc"], {}), true);

      expect(evaluator.evalOperatorCondition("\$nin", "abc", ["abc"], {}), false);
    });

    group('Case-insensitive membership operators', () {
      final evaluator = GBConditionEvaluator();

      // $ini — basic string case-insensitivity
      test('\$ini matches string regardless of case', () {
        expect(evaluator.evalOperatorCondition("\$ini", "Hello", ["hello"], {}), true);
        expect(evaluator.evalOperatorCondition("\$ini", "WORLD", ["world", "foo"], {}), true);
        expect(evaluator.evalOperatorCondition("\$ini", "bar", ["BAZ"], {}), false);
      });

      // $ini — non-string values compared as-is (intentional: no lowercasing)
      test('\$ini compares non-string values as-is', () {
        expect(evaluator.evalOperatorCondition("\$ini", 42, [42, "hello"], {}), true);
        expect(evaluator.evalOperatorCondition("\$ini", 42, [43], {}), false);
        expect(evaluator.evalOperatorCondition("\$ini", null, [null], {}), true);
        expect(evaluator.evalOperatorCondition("\$ini", null, ["null"], {}), false);
        expect(evaluator.evalOperatorCondition("\$ini", true, [true], {}), true);
        expect(evaluator.evalOperatorCondition("\$ini", false, [true], {}), false);
      });

      // $ini — mixed-type list attribute
      test('\$ini with list attribute containing mixed types', () {
        expect(evaluator.evalOperatorCondition("\$ini", ["Hello", 42], ["hello"], {}), true);
        expect(evaluator.evalOperatorCondition("\$ini", ["Hello", 42], [42], {}), true);
        expect(evaluator.evalOperatorCondition("\$ini", ["Hello", 42], ["HELLO", 42], {}), true);
        expect(evaluator.evalOperatorCondition("\$ini", ["foo", 1], ["bar", 2], {}), false);
        expect(evaluator.evalOperatorCondition("\$ini", [], ["hello"], {}), false);
      });

      // $nini
      test('\$nini returns false when value matches (case-insensitive)', () {
        expect(evaluator.evalOperatorCondition("\$nini", "Hello", ["hello"], {}), false);
        expect(evaluator.evalOperatorCondition("\$nini", "xyz", ["abc"], {}), true);
        expect(evaluator.evalOperatorCondition("\$nini", 42, [42], {}), false);
        expect(evaluator.evalOperatorCondition("\$nini", 42, [43], {}), true);
      });

      // $alli — all conditions must match at least one attribute element
      test('\$alli matches all conditions case-insensitively', () {
        expect(evaluator.evalOperatorCondition("\$alli", ["Hello", "World"], ["hello", "world"], {}), true);
        expect(evaluator.evalOperatorCondition("\$alli", ["Hello", "World"], ["HELLO", "WORLD"], {}), true);
        expect(evaluator.evalOperatorCondition("\$alli", ["Hello"], ["world"], {}), false);
      });

      // $alli — non-string elements compared as-is
      test('\$alli with non-string values in attribute list', () {
        expect(evaluator.evalOperatorCondition("\$alli", ["hello", 42], ["HELLO", 42], {}), true);
        expect(evaluator.evalOperatorCondition("\$alli", ["hello", 42], ["HELLO", 43], {}), false);
        expect(evaluator.evalOperatorCondition("\$alli", [null, "foo"], [null, "FOO"], {}), true);
      });

      // $alli — non-list attributeValue returns false
      test('\$alli returns false when attribute is not a list', () {
        expect(evaluator.evalOperatorCondition("\$alli", "hello", ["hello"], {}), false);
        expect(evaluator.evalOperatorCondition("\$alli", 42, [42], {}), false);
      });
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
      GBConditionEvaluator().isEvalCondition(
        jsonDecode(attributes),
        jsonDecode(condition),
        {},
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
      GBConditionEvaluator().isEvalCondition(
        jsonDecode(attributes),
        jsonDecode(condition),
        {},
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
      GBConditionEvaluator().isEvalCondition(
        jsonDecode(attributes),
        jsonDecode(condition),
        {},
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
      GBConditionEvaluator().isEvalCondition(
        jsonDecode(attributes),
        jsonDecode(condition),
        {},
      ),
      false,
    );
  });
}
