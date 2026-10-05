import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// `$lt` / `$lte` / `$gt` / `$gte` against operands that are not both numbers.
///
/// The reference SDK compares with JavaScript's relational operators: two
/// strings compare as text, anything else is converted with `Number()` first. A
/// value with no numeric reading becomes `NaN`, and every comparison with `NaN`
/// is false.
///
/// This SDK used to turn such a value into 0 instead — `"abc"` was less than
/// `1` — and read a boolean as 0 either way, so `true` was not greater than `0`.
/// `double.tryParse` also differs from `Number()` at the edges: it rejects
/// `"0x10"`.
///
/// The shared spec fixtures only compare numbers with numbers and strings with
/// strings. Hence this suite.
void main() {
  group('Range operators', () {
    test('numbers and strings are unchanged', () {
      expect(_eval(r'{"v": {"$gt": 9}}', r'{"v": 10}'), isTrue);
      expect(_eval(r'{"v": {"$lt": "banana"}}', r'{"v": "apple"}'), isTrue);
    });

    /// Two strings compare as text even when both look numeric: "3" sorts
    /// after "1", so `"3" < "10"` is false.
    test('two numeric-looking strings compare as text', () {
      expect(_eval(r'{"v": {"$lt": "10"}}', r'{"v": "3"}'), isFalse);
      expect(_eval(r'{"v": {"$lt": "9"}}', r'{"v": "10"}'), isTrue);
    });

    /// Text compares by UTF-16 code unit, which puts uppercase before
    /// lowercase.
    test('two strings compare by code unit', () {
      expect(_eval(r'{"v": {"$lt": "apple"}}', r'{"v": "Zebra"}'), isTrue);
    });

    /// A value with no numeric reading is `NaN`, so no direction holds — it
    /// used to be 0.
    test('a non-numeric string matches no direction', () {
      for (final op in ['lt', 'lte', 'gt', 'gte']) {
        expect(_eval('{"v": {"\$$op": 1}}', r'{"v": "abc"}'), isFalse,
            reason: '\$$op, "abc"');
        expect(_eval('{"v": {"\$$op": "abc"}}', r'{"v": 1}'), isFalse,
            reason: '\$$op vs "abc"');
      }
    });

    /// A type suffix and the literal `nan` are not JavaScript numbers.
    test('forms JavaScript does not read are NaN', () {
      expect(_eval(r'{"v": {"$lt": 2}}', r'{"v": "1f"}'), isFalse);
      expect(_eval(r'{"v": {"$lt": 2}}', r'{"v": "nan"}'), isFalse);
    });
  });
}

bool _eval(String condition, String attributes) =>
    GBConditionEvaluator().isEvalCondition(
      jsonDecode(attributes) as Map<String, dynamic>,
      jsonDecode(condition),
      null,
    );
