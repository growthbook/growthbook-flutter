import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// `$exists` and the value it is given.
///
/// The reference SDK reads that value in a boolean context
/// (`mongrule.ts`: `return expected ? actual != null : actual == null`), so it
/// follows JavaScript truthiness rather than requiring a JSON boolean. Only the
/// text "true" / "false" used to be recognised here: any other value matched in
/// neither direction.
///
/// GrowthBook's own UI only ever writes a boolean, so the shared spec fixtures
/// have no case for anything else. Hence this suite.
void main() {
  group('Exists operator', () {
    test('boolean values are unchanged', () {
      expect(_eval(r'{"v": {"$exists": true}}', r'{"v": 1}'), isTrue);
      expect(_eval(r'{"v": {"$exists": true}}', r'{}'), isFalse);
      expect(_eval(r'{"v": {"$exists": false}}', r'{}'), isTrue);
      expect(_eval(r'{"v": {"$exists": false}}', r'{"v": 1}'), isFalse);
    });

    /// A stored null is not present, in either direction, as `actual != null`
    /// is false for it in JavaScript.
    test('a stored null is not present', () {
      expect(_eval(r'{"v": {"$exists": true}}', r'{"v": null}'), isFalse);
      expect(_eval(r'{"v": {"$exists": false}}', r'{"v": null}'), isTrue);
    });

    /// A falsy value — `0`, `""`, `null` — asks for an absent attribute, like
    /// `false`.
    test('falsy values ask for an absent attribute', () {
      for (final value in ['0', '""', 'null']) {
        expect(_eval('{"v": {"\$exists": $value}}', '{}'), isTrue,
            reason: '\$exists: $value, absent');
        expect(_eval('{"v": {"\$exists": $value}}', '{"v": 1}'), isFalse,
            reason: '\$exists: $value, present');
      }
    });

    /// Any other value asks for a present attribute. That includes the string
    /// "false", which is a non-empty string and therefore truthy in JavaScript.
    test('truthy values ask for a present attribute', () {
      for (final value in ['1', '-1', '"yes"', '"false"', '[]', '{}']) {
        expect(_eval('{"v": {"\$exists": $value}}', '{"v": 1}'), isTrue,
            reason: '\$exists: $value, present');
        expect(_eval('{"v": {"\$exists": $value}}', '{}'), isFalse,
            reason: '\$exists: $value, absent');
      }
    });
  });
}

bool _eval(String condition, String attributes) =>
    GBConditionEvaluator().isEvalCondition(
      jsonDecode(attributes) as Map<String, dynamic>,
      jsonDecode(condition),
      null,
    );
