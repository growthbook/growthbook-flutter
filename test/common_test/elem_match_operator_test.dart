import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// `$elemMatch` element selection.
///
/// Two opposite mistakes are possible here, and the suite has to pin both
/// sides:
///
/// 1. **Testing null elements.** The reference SDK skips them, so `[null]`
///    satisfies nothing. We used to test every element, which made any
///    negation-flavoured body — `$ne`, `$nin`, `$exists: false`, `$eq: null` —
///    match an array that merely contained a null.
/// 2. **Skipping falsy elements.** `0`, `false` and `""` are ordinary values.
///    Guarding the loop on truthiness rather than nullness is exactly the
///    defect the reference SDK carried until sdk-js #6323, where
///    `{"nums": {"$elemMatch": {"$eq": 0}}}` could not match `[0]`.
///
/// Neither side is covered by the shared spec fixtures (`cases.json`, spec
/// 0.8.0): its eight `$elemMatch` cases all use string elements and non-null
/// arrays, and the #6323 cases went into sdk-js's own test file rather than the
/// shared suite. So a regression in either direction would pass the
/// spec-driven suite in silence.
void main() {
  group('ElemMatch operator', () {
    test('null element does not satisfy an equality on null', () {
      expect(eval(r'{"n": {"$elemMatch": {"$eq": null}}}', r'{"n": [null]}'),
          isFalse);
    });

    test('null element does not satisfy exists false', () {
      expect(
        eval(r'{"n": {"$elemMatch": {"$exists": false}}}', r'{"n": [null]}'),
        isFalse,
      );
    });

    /// The shape that makes this matter in practice: an exclusion inside
    /// `$elemMatch`. A null element is not a member of the list, so testing it
    /// would report a match for an array that holds nothing but nulls.
    test('null element does not satisfy an exclusion', () {
      expect(eval(r'{"n": {"$elemMatch": {"$nin": ["a"]}}}', r'{"n": [null]}'),
          isFalse);
      expect(eval(r'{"n": {"$elemMatch": {"$ne": "a"}}}', r'{"n": [null]}'),
          isFalse);
    });

    test('an array of only nulls matches nothing', () {
      expect(
        eval(r'{"n": {"$elemMatch": {"$nin": ["a"]}}}', r'{"n": [null, null]}'),
        isFalse,
      );
      expect(
        eval(r'{"n": {"$elemMatch": {"$exists": false}}}',
            r'{"n": [null, null]}'),
        isFalse,
      );
    });

    /// Guards against "fixing" the null skip by widening it to truthiness,
    /// which would reintroduce sdk-js #6323 here.
    test('zero element is tested', () {
      expect(eval(r'{"n": {"$elemMatch": {"$eq": 0}}}', r'{"n": [0]}'), isTrue);
      expect(eval(r'{"n": {"$elemMatch": {"$eq": 0}}}', r'{"n": [3, 0, 7]}'),
          isTrue);
    });

    test('false element is tested', () {
      expect(eval(r'{"n": {"$elemMatch": {"$eq": false}}}', r'{"n": [false]}'),
          isTrue);
    });

    test('empty string element is tested', () {
      expect(
          eval(r'{"n": {"$elemMatch": {"$eq": ""}}}', r'{"n": [""]}'), isTrue);
    });

    test('falsy elements are tested alongside nulls', () {
      expect(eval(r'{"n": {"$elemMatch": {"$eq": 0}}}', r'{"n": [null, 0]}'),
          isTrue);
      expect(
        eval(r'{"n": {"$elemMatch": {"$eq": false}}}', r'{"n": [null, false]}'),
        isTrue,
      );
    });

    test('matching element is found after a null', () {
      expect(
          eval(r'{"n": {"$elemMatch": {"$eq": "a"}}}', r'{"n": [null, "a"]}'),
          isTrue);
    });

    test('matching element is found before a null', () {
      expect(
          eval(r'{"n": {"$elemMatch": {"$eq": "a"}}}', r'{"n": ["a", null]}'),
          isTrue);
    });

    test('exclusion still matches on a non-null element', () {
      expect(
        eval(r'{"n": {"$elemMatch": {"$nin": ["z"]}}}', r'{"n": [null, "a"]}'),
        isTrue,
      );
    });

    test('comparison operators see past a null', () {
      expect(eval(r'{"n": {"$elemMatch": {"$gt": 5}}}', r'{"n": [null, 9]}'),
          isTrue);
      expect(eval(r'{"n": {"$elemMatch": {"$gt": 5}}}', r'{"n": [null, 1]}'),
          isFalse);
    });

    /// A non-operator condition is evaluated against the element as an object,
    /// nulls aside.
    test('object condition sees past a null', () {
      expect(
        eval(
            r'{"n": {"$elemMatch": {"k": "v"}}}', r'{"n": [null, {"k": "v"}]}'),
        isTrue,
      );
      expect(
        eval(r'{"n": {"$elemMatch": {"k": "v"}}}',
            r'{"n": [null, {"k": "other"}]}'),
        isFalse,
      );
    });

    test('non-matching elements return false', () {
      expect(
          eval(r'{"n": {"$elemMatch": {"$eq": "a"}}}', r'{"n": [null, "b"]}'),
          isFalse);
    });

    test('empty array matches nothing', () {
      expect(
          eval(r'{"n": {"$elemMatch": {"$eq": "a"}}}', r'{"n": []}'), isFalse);
    });

    test('non-array attribute matches nothing', () {
      expect(
          eval(r'{"n": {"$elemMatch": {"$eq": "a"}}}', r'{"n": "a"}'), isFalse);
      expect(eval(r'{"n": {"$elemMatch": {"$eq": "a"}}}', r'{"other": "x"}'),
          isFalse);
    });

    test('string elements still match', () {
      expect(eval(r'{"t": {"$elemMatch": {"$eq": "a"}}}', r'{"t": ["a", "b"]}'),
          isTrue);
      expect(eval(r'{"t": {"$elemMatch": {"$eq": "z"}}}', r'{"t": ["a", "b"]}'),
          isFalse);
    });
  });
}

bool eval(String condition, String attributes) =>
    GBConditionEvaluator().isEvalCondition(
      jsonDecode(attributes) as Map<String, dynamic>,
      jsonDecode(condition),
      null,
    );
