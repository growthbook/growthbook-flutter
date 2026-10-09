import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// The `$v*` family against operands that are not strings.
///
/// Both operands used to be treated as strings only, so a number fell back to
/// a placeholder: a payload that sent a build number as a JSON number — the
/// natural shape for an Android `versionCode` — therefore matched no version
/// rule at all, with no error raised anywhere. The reference SDK coerces
/// instead (`util.ts`: `if (typeof input === "number") input = input + ""`).
///
/// What made this hard to spot is that the placeholder is still a valid
/// version, so roughly half the comparisons came out right by accident:
/// `10 $vlt "99"` compared `"0"` against `"99"` and answered true, which is
/// also the correct answer. The suite therefore asserts both directions of each
/// comparison, where a placeholder cannot satisfy both.
///
/// The shared spec fixtures (`cases.json`, spec 0.8.0) only ever pass version
/// strings.
void main() {
  group('Version operators', () {
    test('string operands on both sides', () {
      _expectTenIsGreaterThanNine('"10"', '"9"');
      _expectVersionsEqual('"10"', '"10"');
    });

    test('semver strings still compare', () {
      expect(_eval(r'{"v": {"$vgt": "1.0.0"}}', r'{"v": "1.2.0"}'), isTrue);
      expect(_eval(r'{"v": {"$vlt": "1.2.10"}}', r'{"v": "1.2.9"}'), isTrue);
      expect(
        _eval(r'{"v": {"$veq": "1.2.3"}}', r'{"v": "v1.2.3+build99"}'),
        isTrue,
      );
      expect(
        _eval(r'{"v": {"$vgt": "1.0.0-beta"}}', r'{"v": "1.0.0"}'),
        isTrue,
      );
    });

    test('numeric attribute against string condition', () {
      _expectTenIsGreaterThanNine('10', '"9"');
    });

    test('numeric attribute equals string condition', () {
      _expectVersionsEqual('10', '"10"');
    });

    test('string attribute against numeric condition', () {
      _expectTenIsGreaterThanNine('"10"', '9');
    });

    test('string attribute equals numeric condition', () {
      _expectVersionsEqual('"10"', '10');
    });

    test('numeric on both sides', () {
      _expectTenIsGreaterThanNine('10', '9');
      _expectVersionsEqual('10', '10');
    });

    test('large build numbers', () {
      _expectTenIsGreaterThanNine('45210', '9999');
      _expectVersionsEqual('45210', '"45210"');
    });

    /// An integral operand must not be normalised through a double on its way
    /// to a string: past 2^53 that loses digits (`1234567890123456789` becomes
    /// `1234567890123456768`), which would compare a version the payload never
    /// sent. The Dart VM decodes this literal as a 64-bit `int`, so the case is
    /// meaningful here.
    test('large integer operand keeps every digit', () {
      _expectVersionsEqual('1234567890123456789', '"1234567890123456789"');
      expect(
        _eval(
          r'{"v": {"$vne": "1234567890123456768"}}',
          r'{"v": 1234567890123456789}',
        ),
        isTrue,
      );
    });

    /// An integral value must not carry a fractional part into the comparison:
    /// `10.0` would split into two version segments and stop matching `"10"`,
    /// while the reference SDK renders it `10`.
    test('integral decimal renders without fraction', () {
      _expectVersionsEqual('10.0', '"10"');
      _expectTenIsGreaterThanNine('10.0', '"9"');
    });

    test('non-integral decimal keeps its fraction', () {
      _expectVersionsEqual('1.5', '"1.5"');
      expect(_eval(r'{"v": {"$vgt": "1.4"}}', r'{"v": 1.5}'), isTrue);
      expect(_eval(r'{"v": {"$vlt": "1.6"}}', r'{"v": 1.5}'), isTrue);
    });

    test('zero is a version, not a placeholder', () {
      _expectVersionsEqual('0', '"0"');
      expect(_eval(r'{"v": {"$vlt": "1"}}', r'{"v": 0}'), isTrue);
    });

    /// Absent, null, boolean and empty-string operands all fall back to
    /// version `"0"`, as in the reference SDK. Asserting both directions keeps
    /// that a deliberate value rather than something that merely happens to
    /// satisfy one comparison.
    test('absent attribute is version zero', () {
      expect(_eval(r'{"v": {"$vlt": "1"}}', r'{"other": "x"}'), isTrue);
      expect(_eval(r'{"v": {"$vgt": "1"}}', r'{"other": "x"}'), isFalse);
      expect(_eval(r'{"v": {"$veq": "0"}}', r'{"other": "x"}'), isTrue);
    });

    test('null attribute is version zero', () {
      expect(_eval(r'{"v": {"$vlt": "1"}}', r'{"v": null}'), isTrue);
      expect(_eval(r'{"v": {"$vgt": "1"}}', r'{"v": null}'), isFalse);
    });

    test('boolean attribute is version zero', () {
      expect(_eval(r'{"v": {"$veq": "0"}}', r'{"v": true}'), isTrue);
      expect(_eval(r'{"v": {"$veq": "0"}}', r'{"v": false}'), isTrue);
    });

    test('empty string is version zero', () {
      expect(_eval(r'{"v": {"$veq": "0"}}', r'{"v": ""}'), isTrue);
      expect(_eval(r'{"v": {"$vlt": "1"}}', r'{"v": ""}'), isTrue);
    });

    /// Rendering the operand is only half the job — the operator has to be
    /// reached at all. Array and object attributes are routed to the
    /// `$elemMatch` / `$size` branch, so confining the version operators to
    /// primitive attributes made them skip the comparison entirely and answer
    /// false both ways, rather than comparing as version `"0"`.
    test('array attribute is version zero', () {
      expect(_eval(r'{"v": {"$veq": "0"}}', r'{"v": ["1.0.0"]}'), isTrue);
      expect(_eval(r'{"v": {"$vlt": "1"}}', r'{"v": ["1.0.0"]}'), isTrue);
      expect(_eval(r'{"v": {"$vgt": "1"}}', r'{"v": ["1.0.0"]}'), isFalse);
    });

    test('object attribute is version zero', () {
      expect(_eval(r'{"v": {"$veq": "0"}}', r'{"v": {"major": 1}}'), isTrue);
      expect(_eval(r'{"v": {"$vlt": "1"}}', r'{"v": {"major": 1}}'), isTrue);
      expect(_eval(r'{"v": {"$vgt": "1"}}', r'{"v": {"major": 1}}'), isFalse);
    });

    test('array condition is version zero', () {
      expect(_eval(r'{"v": {"$vgt": ["9"]}}', r'{"v": "1.0.0"}'), isTrue);
      expect(_eval(r'{"v": {"$veq": ["9"]}}', r'{"v": "0"}'), isTrue);
    });
  });
}

/// Evaluates [condition] against [attributes], both decoded from JSON so their
/// shapes match what the SDK receives from the network.
bool _eval(String condition, String attributes) =>
    GBConditionEvaluator().isEvalCondition(
      jsonDecode(attributes) as Map<String, dynamic>,
      jsonDecode(condition),
      null,
    );

/// Asserts the whole operator family at once for a `10` vs `9` pair, however
/// each is encoded.
void _expectTenIsGreaterThanNine(String ten, String nine) {
  final attrs = '{"v": $ten}';
  expect(_eval('{"v": {"\$vgt": $nine}}', attrs), isTrue, reason: r'$vgt');
  expect(_eval('{"v": {"\$vgte": $nine}}', attrs), isTrue, reason: r'$vgte');
  expect(_eval('{"v": {"\$vne": $nine}}', attrs), isTrue, reason: r'$vne');
  expect(_eval('{"v": {"\$vlt": $nine}}', attrs), isFalse, reason: r'$vlt');
  expect(_eval('{"v": {"\$vlte": $nine}}', attrs), isFalse, reason: r'$vlte');
  expect(_eval('{"v": {"\$veq": $nine}}', attrs), isFalse, reason: r'$veq');
}

/// Asserts the whole family for a pair that is equal, however each side is
/// encoded.
void _expectVersionsEqual(String left, String right) {
  final attrs = '{"v": $left}';
  expect(_eval('{"v": {"\$veq": $right}}', attrs), isTrue, reason: r'$veq');
  expect(_eval('{"v": {"\$vgte": $right}}', attrs), isTrue, reason: r'$vgte');
  expect(_eval('{"v": {"\$vlte": $right}}', attrs), isTrue, reason: r'$vlte');
  expect(_eval('{"v": {"\$vne": $right}}', attrs), isFalse, reason: r'$vne');
  expect(_eval('{"v": {"\$vgt": $right}}', attrs), isFalse, reason: r'$vgt');
  expect(_eval('{"v": {"\$vlt": $right}}', attrs), isFalse, reason: r'$vlt');
}
