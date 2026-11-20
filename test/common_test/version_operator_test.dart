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

    test('numeric on both sides', () {
      _expectTenIsGreaterThanNine('10', '9');
      _expectVersionsEqual('10', '10');
    });

    test('empty string is version zero', () {
      expect(_eval(r'{"v": {"$veq": "0"}}', r'{"v": ""}'), isTrue);
      expect(_eval(r'{"v": {"$vlt": "1"}}', r'{"v": ""}'), isTrue);
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
