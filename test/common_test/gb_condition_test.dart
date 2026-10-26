import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Evaluator/condition_evaluator.dart';
import 'package:growthbook_sdk_flutter/src/Utils/js_json.dart';

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
        final result = evaluator.isEvalCondition(
            item[2], item[1], item.length == 5 ? item[4] : {});
        final status =
            "${item[0]}\nExpected Result - ${item[3]}\nActual result - $result\n\n";
        if (item[3].toString() == result.toString()) {
          passedScenarios.add(status);
        } else {
          failedScenarios.add(status);
          failedIndex.add(index);
        }
        index++;
      }
      expect(failedScenarios, isEmpty);
      logger.i(
          'Passed Test ${passedScenarios.length} out of ${evaluateCondition.length}');
    });

    test('A malformed condition fails instead of throwing', () {
      final evaluator = GBConditionEvaluator();
      expect(evaluator.isEvalCondition({}, {'\$or': null}, {}), false);
      expect(
          evaluator.isEvalCondition({}, {
            '\$and': [null]
          }, {}),
          false);
      expect(
          evaluator.isEvalCondition({}, {
            '\$not': {'\$or': null}
          }, {}),
          false);
    });

    test('NaN and negative zero compare like JavaScript numbers', () {
      final evaluator = GBConditionEvaluator();
      bool check(String op, dynamic attribute, dynamic value) =>
          evaluator.isEvalCondition({
            'a': attribute
          }, {
            'a': {op: value}
          }, {});

      for (final op in ['\$gt', '\$gte', '\$lt', '\$lte']) {
        expect(check(op, double.nan, 1), false, reason: 'NaN $op 1');
        expect(check(op, 1, double.nan), false, reason: '1 $op NaN');
      }
      expect(check('\$lt', -0.0, 0), false);
      expect(check('\$gt', 0, -0.0), false);
      expect(check('\$gte', -0.0, 0), true);
      expect(check('\$lte', 0, -0.0), true);
    });

    test('Integer and double values in arrays and objects are equal', () {
      final evaluator = GBConditionEvaluator();
      bool check(dynamic attribute, dynamic condition) =>
          evaluator.isEvalCondition({'a': attribute}, {'a': condition}, {});

      expect(check([1.0], [1]), true);
      expect(check([1], [1.0]), true);
      expect(check({'b': 1.0}, {'b': 1}), true);
      expect(
          check([
            {
              'b': [2.0, -0.0]
            }
          ], [
            {
              'b': [2, 0]
            }
          ]),
          true);
      expect(check([1.5], [1]), false);
      // Key order still matters, except integer keys sort first as in JS
      expect(check({'b': 1, 'c': 2}, {'c': 2, 'b': 1}), false);
      expect(check({'b': 1, '1': 2}, {'1': 2, 'b': 1}), true);
      // JSON.stringify writes NaN as null
      expect(check([double.nan], [null]), true);
      // Large numbers compare as JS binary64 values
      expect(
          check(jsonDecode('[1000000000000000100.0]'),
              jsonDecode('[1000000000000000100]')),
          true);
      expect(check([1e18], [1000000000000000001]), true);
      expect(check([1e18], [1000000000000000200]), false);
    });

    test('jsNumberToString matches JavaScript', () {
      expect(jsNumberToString(1), '1');
      expect(jsNumberToString(1.0), '1');
      expect(jsNumberToString(1.5), '1.5');
      expect(jsNumberToString(1e21), '1e+21');
      expect(jsNumberToString(1e-7), '1e-7');
      expect(jsNumberToString(0.000002), '0.000002');
      expect(jsNumberToString(123e-20), '1.23e-18');
      expect(jsNumberToString(1e23), '1e+23');
      expect(jsNumberToString(-0.0), '0');
      expect(jsNumberToString(1e20), '100000000000000000000');
      expect(jsNumberToString(-2.5), '-2.5');
      expect(jsNumberToString(double.nan), 'NaN');
      expect(jsNumberToString(double.negativeInfinity), '-Infinity');
      // Shortest round-trip digits, not the exact binary value
      expect(jsNumberToString(1000000000000000100.0), '1000000000000000100');
      expect(jsNumberToString(1000000000000000128), '1000000000000000100');
      expect(
          jsNumberToString(123456789012345680000.0), '123456789012345680000');
      expect(jsNumberToString(9007199254740993), '9007199254740992');
      expect(jsNumberToString(-1e15), '-1000000000000000');
      expect(jsNumberToString(9223372036854775807), '9223372036854776000');
    });

    test('Test valid condition obj', () {
      final evaluator = GBConditionEvaluator();

      expect(evaluator.isEvalCondition({}, [], {}), false);

      // An empty object has no operators, so it always passes
      expect(evaluator.isOperatorObject({}), true);

      expect(evaluator.getPath('test', 'key'), null);

      expect(
          evaluator.isEvalConditionValue(<String, dynamic>{}, null, {}), true);

      expect(evaluator.evalOperatorCondition("\$lte", "abc", "abc", {}), true);

      expect(evaluator.evalOperatorCondition("\$gte", "abc", "abc", {}), true);

      expect(evaluator.evalOperatorCondition("\$vlt", "0.9.0", "0.10.0", {}),
          true);

      expect(evaluator.evalOperatorCondition("\$in", "abc", ["abc"], {}), true);

      expect(
          evaluator.evalOperatorCondition("\$nin", "abc", ["abc"], {}), false);
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
