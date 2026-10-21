import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Evaluator/condition_evaluator.dart';

/// Plain equality must match the JS SDK (`evalConditionValue` in mongrule.ts).
/// Every expected value below was produced by running the JS SDK.
void main() {
  group('Condition equality matches JS', () {
    void expectCase(
      String name,
      dynamic condition,
      Map<String, dynamic> attributes,
      bool expected,
    ) {
      test(name, () {
        final result = GBConditionEvaluator()
            .isEvalCondition(attributes, <String, dynamic>{'a': condition}, {});
        expect(result, expected, reason: name);
      });
    }

    expectCase(
      'string condition vs integer attribute',
      '10',
      <String, dynamic>{'a': 10},
      true,
    );
    expectCase(
      'string condition vs float attribute 1.5',
      '1.5',
      <String, dynamic>{'a': 1.5},
      true,
    );
    expectCase(
      'string condition vs float attribute 1.0',
      '1',
      <String, dynamic>{'a': 1.0},
      true,
    );
    expectCase(
      'string condition \'1.0\' vs number attribute 1',
      '1.0',
      <String, dynamic>{'a': 1},
      false,
    );
    expectCase(
      'string condition vs large number 1e21',
      '1e+21',
      <String, dynamic>{'a': 1e21},
      true,
    );
    expectCase(
      'string condition vs boolean true',
      'true',
      <String, dynamic>{'a': true},
      true,
    );
    expectCase(
      'string condition vs boolean false',
      'false',
      <String, dynamic>{'a': false},
      true,
    );
    expectCase(
      'string condition \'null\' vs null attribute',
      'null',
      <String, dynamic>{'a': null},
      true,
    );
    expectCase(
      'string condition \'null\' vs missing attribute',
      'null',
      <String, dynamic>{},
      true,
    );
    expectCase(
      'string condition \'undefined\' vs missing attribute',
      'undefined',
      <String, dynamic>{},
      false,
    );
    expectCase(
      'string condition vs array attribute',
      'a,b',
      <String, dynamic>{
        'a': ['a', 'b']
      },
      true,
    );
    expectCase(
      'string condition vs single-element array',
      'a',
      <String, dynamic>{
        'a': ['a']
      },
      true,
    );
    expectCase(
      'string condition vs object attribute',
      '[object Object]',
      <String, dynamic>{
        'a': <String, dynamic>{'x': 1}
      },
      true,
    );
    expectCase(
      'string condition vs different string',
      'abc',
      <String, dynamic>{'a': 'abd'},
      false,
    );
    expectCase(
      'number condition vs numeric string',
      10,
      <String, dynamic>{'a': '10'},
      true,
    );
    expectCase(
      'number condition vs padded numeric string',
      10,
      <String, dynamic>{'a': ' 10 '},
      true,
    );
    expectCase(
      'number condition vs decimal string',
      1.5,
      <String, dynamic>{'a': '1.5'},
      true,
    );
    expectCase(
      'number condition vs hex string',
      16,
      <String, dynamic>{'a': '0x10'},
      true,
    );
    expectCase(
      'number condition vs exponent string',
      1000,
      <String, dynamic>{'a': '1e3'},
      true,
    );
    expectCase(
      'number 0 condition vs empty string',
      0,
      <String, dynamic>{'a': ''},
      true,
    );
    expectCase(
      'number condition vs non-numeric string',
      10,
      <String, dynamic>{'a': '10abc'},
      false,
    );
    expectCase(
      'number 1 condition vs boolean true',
      1,
      <String, dynamic>{'a': true},
      true,
    );
    expectCase(
      'number 0 condition vs boolean false',
      0,
      <String, dynamic>{'a': false},
      true,
    );
    expectCase(
      'number 0 condition vs null attribute',
      0,
      <String, dynamic>{'a': null},
      true,
    );
    expectCase(
      'number 0 condition vs missing attribute',
      0,
      <String, dynamic>{},
      true,
    );
    expectCase(
      'number 1 condition vs missing attribute',
      1,
      <String, dynamic>{},
      false,
    );
    expectCase(
      'number 1 condition vs float attribute 1.0',
      1,
      <String, dynamic>{'a': 1.0},
      true,
    );
    expectCase(
      'number 1.0 condition vs integer attribute 1',
      1.0,
      <String, dynamic>{'a': 1},
      true,
    );
    expectCase(
      'number condition vs different number',
      2,
      <String, dynamic>{'a': 1},
      false,
    );
    expectCase(
      'number condition vs single-element array',
      5,
      <String, dynamic>{
        'a': [5]
      },
      true,
    );
    expectCase(
      'number condition vs two-element array',
      5,
      <String, dynamic>{
        'a': [5, 6]
      },
      false,
    );
    expectCase(
      'number 0 condition vs empty array',
      0,
      <String, dynamic>{'a': []},
      true,
    );
    expectCase(
      'number condition vs object attribute',
      0,
      <String, dynamic>{'a': <String, dynamic>{}},
      false,
    );
    expectCase(
      'boolean true vs string \'true\'',
      true,
      <String, dynamic>{'a': 'true'},
      true,
    );
    expectCase(
      'boolean false vs string \'false\'',
      false,
      <String, dynamic>{'a': 'false'},
      false,
    );
    expectCase(
      'boolean true vs string \'0\'',
      true,
      <String, dynamic>{'a': '0'},
      true,
    );
    expectCase(
      'boolean false vs empty string',
      false,
      <String, dynamic>{'a': ''},
      true,
    );
    expectCase(
      'boolean false vs number 0',
      false,
      <String, dynamic>{'a': 0},
      true,
    );
    expectCase(
      'boolean true vs number 1',
      true,
      <String, dynamic>{'a': 1},
      true,
    );
    expectCase(
      'boolean true vs float 0.5',
      true,
      <String, dynamic>{'a': 0.5},
      true,
    );
    expectCase(
      'boolean false vs null attribute',
      false,
      <String, dynamic>{'a': null},
      false,
    );
    expectCase(
      'boolean true vs null attribute',
      true,
      <String, dynamic>{'a': null},
      false,
    );
    expectCase(
      'boolean false vs missing attribute',
      false,
      <String, dynamic>{},
      false,
    );
    expectCase(
      'boolean true vs empty array',
      true,
      <String, dynamic>{'a': []},
      true,
    );
    expectCase(
      'boolean true vs empty object',
      true,
      <String, dynamic>{'a': <String, dynamic>{}},
      true,
    );
    expectCase(
      'null condition vs null attribute',
      null,
      <String, dynamic>{'a': null},
      true,
    );
    expectCase(
      'null condition vs missing attribute',
      null,
      <String, dynamic>{},
      true,
    );
    expectCase(
      'null condition vs string \'null\'',
      null,
      <String, dynamic>{'a': 'null'},
      false,
    );
    expectCase(
      'null condition vs number 0',
      null,
      <String, dynamic>{'a': 0},
      false,
    );
    expectCase(
      'array condition vs equal array',
      [1, 2],
      <String, dynamic>{
        'a': [1, 2]
      },
      true,
    );
    expectCase(
      'array condition vs float array',
      [1, 2],
      <String, dynamic>{
        'a': [1.0, 2.0]
      },
      true,
    );
    expectCase(
      'array condition vs reordered array',
      [1, 2],
      <String, dynamic>{
        'a': [2, 1]
      },
      false,
    );
    expectCase(
      'array condition vs string attribute',
      ['a'],
      <String, dynamic>{'a': 'a'},
      false,
    );
    expectCase(
      'array condition vs nested array',
      [
        [1],
        <String, dynamic>{'x': 'y'}
      ],
      <String, dynamic>{
        'a': [
          [1],
          <String, dynamic>{'x': 'y'}
        ]
      },
      true,
    );
    expectCase(
      'object condition vs equal object',
      <String, dynamic>{'x': 1, 'y': 2},
      <String, dynamic>{
        'a': <String, dynamic>{'x': 1, 'y': 2}
      },
      true,
    );
    expectCase(
      'object condition vs reordered keys',
      <String, dynamic>{'x': 1, 'y': 2},
      <String, dynamic>{
        'a': <String, dynamic>{'y': 2, 'x': 1}
      },
      false,
    );
    expectCase(
      'object condition vs nested object',
      <String, dynamic>{
        'x': <String, dynamic>{
          'y': [1, 'a']
        }
      },
      <String, dynamic>{
        'a': <String, dynamic>{
          'x': <String, dynamic>{
            'y': [1, 'a']
          }
        }
      },
      true,
    );
    expectCase(
      'object condition vs nested float',
      <String, dynamic>{
        'x': <String, dynamic>{'y': 1}
      },
      <String, dynamic>{
        'a': {
          'x': {'y': 1.0}
        }
      },
      true,
    );
    expectCase(
      'object condition vs null attribute',
      <String, dynamic>{'x': 1},
      <String, dynamic>{'a': null},
      false,
    );
    expectCase(
      'object condition vs string attribute',
      <String, dynamic>{'x': 1},
      <String, dynamic>{'a': '[object Object]'},
      false,
    );
    expectCase(
      '\$not with number condition vs numeric string',
      <String, dynamic>{'\$not': 10},
      <String, dynamic>{'a': '10'},
      false,
    );
    expectCase(
      '\$size with string condition',
      <String, dynamic>{'\$size': '2'},
      <String, dynamic>{
        'a': [1, 2]
      },
      true,
    );
    expectCase(
      '\$all with number condition vs numeric strings',
      <String, dynamic>{
        '\$all': [1]
      },
      <String, dynamic>{
        'a': ['1', '2']
      },
      true,
    );
    expectCase(
      '\$alli with string condition vs number element',
      <String, dynamic>{
        '\$alli': ['ABC']
      },
      <String, dynamic>{
        'a': ['abc', 2]
      },
      true,
    );
  });
}
