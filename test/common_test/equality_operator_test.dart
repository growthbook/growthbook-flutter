import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// `$eq` / `$ne` across every attribute type.
///
/// `$eq` used to narrow both operands to strings before comparing, so it
/// answered false for every number and boolean: `{"age": {"$eq": 25}}` did not
/// match an age of 25, and `$eq` and `$ne` both reported false for the same
/// pair — a self-contradiction that is impossible to read as anything but a
/// bug. The reference SDK compares the decoded values directly (`mongrule.ts`:
/// `case "$eq": return actual === expected`).
///
/// The shared spec fixtures (`cases.json`, spec 0.8.0) only ever pair `$eq`
/// with a string, plus one boolean case against a *missing* attribute that
/// expects false — which the broken version passed for the wrong reason. Hence
/// this suite.
///
/// Plain equality (`{"age": 25}`) goes through a different path in
/// `isEvalConditionValue` and was never affected; it is covered here too so the
/// two stay in agreement.
void main() {
  group('Equality operators', () {
    test('eq matches an equal integer', () {
      expect(_eval(r'{"age": {"$eq": 25}}', r'{"age": 25}'), isTrue);
    });

    test('eq does not match a different integer', () {
      expect(_eval(r'{"age": {"$eq": 25}}', r'{"age": 30}'), isFalse);
    });

    test('eq matches an equal decimal', () {
      expect(_eval(r'{"score": {"$eq": 1.5}}', r'{"score": 1.5}'), isTrue);
    });

    test('eq matches a negative number', () {
      expect(_eval(r'{"delta": {"$eq": -3}}', r'{"delta": -3}'), isTrue);
    });

    test('ne is the exact inverse for numbers', () {
      expect(_eval(r'{"age": {"$ne": 25}}', r'{"age": 25}'), isFalse);
      expect(_eval(r'{"age": {"$ne": 25}}', r'{"age": 30}'), isTrue);
    });

    /// Adapted from the Kotlin suite, which pins the opposite answer: its
    /// `GBNumber` deliberately keeps integer and floating-point values distinct,
    /// a Kotlin-only nuance. Dart, like JavaScript's single number type
    /// (`25 === 25.0`), treats `25 == 25.0` as true, so here an integer and an
    /// integral decimal are equal — and consistently so across `$eq`, plain
    /// equality and `$ne`.
    test('integer and integral decimal are equal and consistently so', () {
      final viaEq = _eval(r'{"age": {"$eq": 25}}', r'{"age": 25.0}');
      final viaPlain = _eval(r'{"age": 25}', r'{"age": 25.0}');
      final viaNe = _eval(r'{"age": {"$ne": 25}}', r'{"age": 25.0}');

      expect(viaEq, isTrue, reason: r'$eq must follow the JS reference');
      expect(viaPlain, isTrue, reason: r'plain equality must agree with $eq');
      expect(viaNe, isFalse, reason: r'$ne must stay the exact inverse of $eq');
    });

    test('eq matches an equal boolean', () {
      expect(_eval(r'{"beta": {"$eq": true}}', r'{"beta": true}'), isTrue);
      expect(_eval(r'{"beta": {"$eq": false}}', r'{"beta": false}'), isTrue);
    });

    test('eq does not match the opposite boolean', () {
      expect(_eval(r'{"beta": {"$eq": true}}', r'{"beta": false}'), isFalse);
    });

    test('ne is the exact inverse for booleans', () {
      expect(_eval(r'{"beta": {"$ne": true}}', r'{"beta": true}'), isFalse);
      expect(_eval(r'{"beta": {"$ne": true}}', r'{"beta": false}'), isTrue);
    });

    test('eq matches an equal string', () {
      expect(_eval(r'{"c": {"$eq": "US"}}', r'{"c": "US"}'), isTrue);
    });

    test('eq is case sensitive', () {
      expect(_eval(r'{"c": {"$eq": "US"}}', r'{"c": "us"}'), isFalse);
    });

    test('eq does not match across types', () {
      expect(_eval(r'{"v": {"$eq": "25"}}', r'{"v": 25}'), isFalse);
      expect(_eval(r'{"v": {"$eq": 25}}', r'{"v": "25"}'), isFalse);
      expect(_eval(r'{"v": {"$eq": true}}', r'{"v": "true"}'), isFalse);
    });

    test('eq matches null against an explicitly null attribute', () {
      expect(_eval(r'{"c": {"$eq": null}}', r'{"c": null}'), isTrue);
    });

    /// `getPath` collapses a missing attribute to null, exactly as the
    /// reference SDK does.
    test('eq matches null against an absent attribute', () {
      expect(_eval(r'{"c": {"$eq": null}}', r'{"other": "x"}'), isTrue);
    });

    test('eq does not match a value against an absent attribute', () {
      expect(_eval(r'{"c": {"$eq": "US"}}', r'{"other": "x"}'), isFalse);
      expect(_eval(r'{"c": {"$eq": false}}', r'{"other": "x"}'), isFalse);
      expect(_eval(r'{"c": {"$eq": 0}}', r'{"other": "x"}'), isFalse);
    });

    test('eq agrees with plain equality for null', () {
      expect(_eval(r'{"c": {"$eq": null}}', r'{"other": "x"}'), isTrue);
      expect(_eval(r'{"c": null}', r'{"other": "x"}'), isTrue);
    });

    /// The reference SDK compares with `===`: value equality for primitives,
    /// reference identity for arrays and objects. A condition and an attribute
    /// are always decoded from separate JSON, so a non-primitive operand is
    /// never identical and `$eq` is false whatever the contents.
    ///
    /// That is reproduced rather than deepened into a content comparison. A
    /// deep `$eq` would match here and not on the other SDKs, and a rule that
    /// behaves differently per platform is worse than one that is uniformly
    /// useless — the opposite trade-off to the `$regex` null case, where the
    /// reference behaviour produced false *positives*.
    ///
    /// Note this leaves `$eq` disagreeing with plain equality on the same
    /// values, since `{"t": ["a"]}` does compare deeply. The inconsistency is
    /// inherited from the reference SDK, which does exactly the same thing, so
    /// 'plain equality still compares contents' pins it.
    test('eq does not match array or object attributes', () {
      expect(_eval(r'{"t": {"$eq": ["a"]}}', r'{"t": ["a"]}'), isFalse);
      expect(
        _eval(r'{"t": {"$eq": {"k": "v"}}}', r'{"t": {"k": "v"}}'),
        isFalse,
      );
    });

    test('plain equality still compares contents', () {
      expect(_eval(r'{"t": ["a"]}', r'{"t": ["a"]}'), isTrue);
      expect(_eval(r'{"t": ["a"]}', r'{"t": ["b"]}'), isFalse);
      expect(_eval(r'{"t": {"k": "v"}}', r'{"t": {"k": "v"}}'), isTrue);
    });

    test('pair is a strict inverse for non-primitive attributes', () {
      _expectStrictInverse(r'["a"]', r'{"t": ["a"]}', expectedEq: false);
      _expectStrictInverse(r'["b"]', r'{"t": ["a"]}', expectedEq: false);
      _expectStrictInverse(
        r'{"k": "v"}',
        r'{"t": {"k": "v"}}',
        expectedEq: false,
      );
      _expectStrictInverse(r'[]', r'{"t": []}', expectedEq: false);
    });

    test('pair is a strict inverse for non-primitive conditions', () {
      _expectStrictInverse(r'["a"]', r'{"t": "a"}', expectedEq: false);
      _expectStrictInverse(r'{"k": "v"}', r'{"t": "a"}', expectedEq: false);
      _expectStrictInverse(r'["a"]', r'{"other": "x"}', expectedEq: false);
    });

    test('pair is a strict inverse for primitives', () {
      _expectStrictInverse(r'"a"', r'{"t": "a"}', expectedEq: true);
      _expectStrictInverse(r'"b"', r'{"t": "a"}', expectedEq: false);
      _expectStrictInverse('25', r'{"t": 25}', expectedEq: true);
      _expectStrictInverse('true', r'{"t": true}', expectedEq: true);
      _expectStrictInverse('null', r'{"t": null}', expectedEq: true);
      _expectStrictInverse('null', r'{"other": "x"}', expectedEq: true);
      _expectStrictInverse(r'"a"', r'{"other": "x"}', expectedEq: false);
    });

    /// `$elemMatch` evaluates its body against each element, so the
    /// string-only `$eq` also made `{"n": {"$elemMatch": {"$eq": 0}}}` miss
    /// `[0]` — the same symptom the reference SDK fixed from the other
    /// direction in sdk-js #6323, where falsy elements were skipped before the
    /// comparison ran.
    test('elemMatch eq matches falsy numeric elements', () {
      const condition = r'{"n": {"$elemMatch": {"$eq": 0}}}';
      expect(_eval(condition, r'{"n": [0]}'), isTrue);
      expect(_eval(condition, r'{"n": [3, 0, 7]}'), isTrue);
      expect(_eval(condition, r'{"n": [3, 7]}'), isFalse);
    });

    test('elemMatch eq matches falsy boolean and string elements', () {
      expect(
        _eval(r'{"n": {"$elemMatch": {"$eq": false}}}', r'{"n": [false]}'),
        isTrue,
      );
      expect(
        _eval(r'{"n": {"$elemMatch": {"$eq": ""}}}', r'{"n": [""]}'),
        isTrue,
      );
    });

    test('elemMatch eq still matches string elements', () {
      expect(
        _eval(r'{"t": {"$elemMatch": {"$eq": "a"}}}', r'{"t": ["a", "b"]}'),
        isTrue,
      );
      expect(
        _eval(r'{"t": {"$elemMatch": {"$eq": "z"}}}', r'{"t": ["a", "b"]}'),
        isFalse,
      );
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

/// Whatever the answer for a given shape, `$eq` and `$ne` must be exact
/// opposites. Both returning false is the signature of the operator never
/// being reached at all, which is what happened for every non-primitive
/// operand while the pair lived in the primitive-attribute branch.
void _expectStrictInverse(
  String condition,
  String attributes, {
  required bool expectedEq,
}) {
  final eq = _eval('{"t": {"\$eq": $condition}}', attributes);
  final ne = _eval('{"t": {"\$ne": $condition}}', attributes);

  expect(
    eq != ne,
    isTrue,
    reason: '\$eq and \$ne both returned $eq for $condition vs $attributes',
  );
  expect(eq, expectedEq, reason: '\$eq for $condition vs $attributes');
}
