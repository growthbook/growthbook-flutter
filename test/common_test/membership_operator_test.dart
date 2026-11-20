import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Covers `$in` / `$ini` / `$nin` / `$nini` across every combination of
/// attribute presence.
///
/// The pair must stay a true logical negation: an attribute the user does not
/// have is genuinely not in the list, so `$in` is false and `$nin` is true.
/// Returning false for both — which is what happens when the array-operator
/// branch is gated on the attribute being non-null and evaluation drops out of
/// it — silently breaks any rule written as an exclusion, such as "serve
/// everyone except these countries".
///
/// The shared spec fixtures pin `$in` with a missing attribute ("missing
/// attribute - fail") but contain no `$nin` case with a missing or null
/// attribute, so that half is only covered here. Reported in
/// growthbook-swift#185, where the same inputs were measured against
/// growthbook-js 1.7.0.
///
/// Ported from the Kotlin SDK's `MembershipOperatorTests`.
void main() {
  bool eval(String condition, String attributes) =>
      GBConditionEvaluator().isEvalCondition(
        jsonDecode(attributes) as Map<String, dynamic>,
        jsonDecode(condition),
        null,
      );

  bool isIn(String attributes) =>
      eval(r'{"country": {"$in": ["RU", "CN"]}}', attributes);

  bool notIn(String attributes) =>
      eval(r'{"country": {"$nin": ["RU", "CN"]}}', attributes);

  /// The shape that surfaced this in practice (growthbook-swift#185): two
  /// exclusions combined, where one attribute only exists after
  /// authentication. Every key in a condition object is ANDed, so the absent
  /// half must not drag the whole rule to false — and must not loosen it
  /// either: the exclusion still has to hold from both sides.
  bool excludeBoth(String attributes) => eval(
        r'{"plan": {"$nin": ["trial"]}, "country": {"$nin": ["RU", "CN"]}}',
        attributes,
      );

  /// `getPath` walks a dotted key and yields null as soon as a segment is
  /// missing, so an exclusion on a nested attribute has to behave like an
  /// absent flat one. This is the shape that bites hardest in practice: the
  /// parent object exists only for authenticated users.
  bool notInNested(String attributes) =>
      eval(r'{"user.country": {"$nin": ["RU", "CN"]}}', attributes);

  /// A JSON array of `size` distinct country codes (`"C1"`, `"C2"`, ...).
  ///
  /// In the Kotlin SDK the list switches from a linear scan to a HashSet at 16
  /// entries; the Dart evaluator has no such index, but the sizes are kept so
  /// any future optimisation is covered by the same inputs.
  String countries(int size) =>
      jsonEncode([for (var i = 1; i <= size; i++) 'C$i']);

  bool notInList(int size, String attributes) =>
      eval('{"country": {"\$nin": ${countries(size)}}}', attributes);

  group(r'$in / $ini / $nin / $nini membership', () {
    test(r'$in matches listed value', () {
      expect(isIn(r'{"country": "RU"}'), isTrue);
    });

    test(r'$in does not match unlisted value', () {
      expect(isIn(r'{"country": "US"}'), isFalse);
    });

    test(r'$nin does not match listed value', () {
      expect(notIn(r'{"country": "RU"}'), isFalse);
    });

    test(r'$nin matches unlisted value', () {
      expect(notIn(r'{"country": "US"}'), isTrue);
    });

    test(r'$in does not match when attribute is absent', () {
      expect(isIn(r'{"unrelated": "x"}'), isFalse,
          reason: r'A user without the attribute is not in the list, '
              r'so $in must not match');
    });

    test(r'$nin matches when attribute is absent', () {
      expect(notIn(r'{"unrelated": "x"}'), isTrue,
          reason: r'A user without the attribute is not in the list, '
              r'so $nin must match');
    });

    test(r'$in does not match when attribute is null', () {
      expect(isIn(r'{"country": null}'), isFalse);
    });

    test(r'$nin matches when attribute is null', () {
      expect(notIn(r'{"country": null}'), isTrue,
          reason: r'null is not a member of the list, so $nin must match');
    });

    test(r'$ini does not match when attribute is absent', () {
      expect(eval(r'{"country": {"$ini": ["ru"]}}', r'{"unrelated": "x"}'),
          isFalse);
    });

    test(r'$nini matches when attribute is absent', () {
      expect(eval(r'{"country": {"$nini": ["ru"]}}', r'{"unrelated": "x"}'),
          isTrue);
    });

    test(r'$ini does not match when attribute is null', () {
      expect(eval(r'{"country": {"$ini": ["ru"]}}', r'{"country": null}'),
          isFalse);
    });

    test(r'$nini matches when attribute is null', () {
      expect(eval(r'{"country": {"$nini": ["ru"]}}', r'{"country": null}'),
          isTrue);
    });

    test(r'$ini still matches regardless of case', () {
      expect(
          eval(r'{"country": {"$ini": ["ru"]}}', r'{"country": "RU"}'), isTrue);
    });

    test(r'$nini still negates a case-insensitive match', () {
      expect(eval(r'{"country": {"$nini": ["ru"]}}', r'{"country": "RU"}'),
          isFalse);
    });

    /// `$all` asks whether every listed value is present in the attribute. An
    /// attribute the user does not have contains nothing, so this stays false —
    /// it is not a negation and must not follow `$nin` out of the gate.
    test(r'$all does not match when attribute is absent', () {
      expect(
          eval(r'{"tags": {"$all": ["a"]}}', r'{"unrelated": "x"}'), isFalse);
    });

    test(r'$alli does not match when attribute is absent', () {
      expect(
          eval(r'{"tags": {"$alli": ["a"]}}', r'{"unrelated": "x"}'), isFalse);
    });

    test(r'$nin matches array attribute with no overlap', () {
      expect(eval(r'{"tags": {"$nin": ["a", "b"]}}', r'{"tags": ["c", "d"]}'),
          isTrue);
    });

    test(r'$nin does not match array attribute with overlap', () {
      expect(eval(r'{"tags": {"$nin": ["a", "b"]}}', r'{"tags": ["c", "a"]}'),
          isFalse);
    });
  });

  group('AND of exclusions', () {
    test('matches when the gated attribute is absent', () {
      expect(excludeBoth(r'{"country": "US"}'), isTrue,
          reason: 'A logged-out user has no plan, so the plan exclusion '
              'holds and the rule applies');
    });

    test('still excludes on the present attribute', () {
      expect(excludeBoth(r'{"country": "RU"}'), isFalse,
          reason: 'The country exclusion must still bite while plan is absent');
    });

    test('still excludes on the gated attribute once it appears', () {
      expect(excludeBoth(r'{"plan": "trial", "country": "US"}'), isFalse,
          reason: 'Once the user authenticates, the plan exclusion must bite');
    });

    test('matches when both attributes are outside the lists', () {
      expect(excludeBoth(r'{"plan": "pro", "country": "US"}'), isTrue);
    });
  });

  group('list size', () {
    test(r'$nin below the set threshold is unaffected by absent attribute', () {
      expect(notInList(15, r'{"unrelated": "x"}'), isTrue);
      expect(notInList(15, r'{"country": null}'), isTrue);
      expect(notInList(15, r'{"country": "ZZ"}'), isTrue);
      expect(notInList(15, r'{"country": "C3"}'), isFalse);
    });

    test(
        r'$nin at and above the set threshold is unaffected by absent attribute',
        () {
      for (final size in [16, 20]) {
        expect(notInList(size, r'{"unrelated": "x"}'), isTrue,
            reason: 'size=$size, absent');
        expect(notInList(size, r'{"country": null}'), isTrue,
            reason: 'size=$size, null');
        expect(notInList(size, r'{"country": "ZZ"}'), isTrue,
            reason: 'size=$size, unlisted');
        expect(notInList(size, r'{"country": "C3"}'), isFalse,
            reason: 'size=$size, listed');
      }
    });

    test(r'$in at the set threshold still fails for absent attribute', () {
      final condition = '{"country": {"\$in": ${countries(20)}}}';
      expect(eval(condition, r'{"unrelated": "x"}'), isFalse);
      expect(eval(condition, r'{"country": null}'), isFalse);
      expect(eval(condition, r'{"country": "C3"}'), isTrue);
    });
  });

  group('nested paths', () {
    test(r'$nin matches when the whole parent object is absent', () {
      expect(notInNested(r'{"unrelated": "x"}'), isTrue);
    });

    test(r'$nin matches when the leaf is absent from an existing parent', () {
      expect(notInNested(r'{"user": {"id": "1199"}}'), isTrue);
    });

    test(r'$nin matches when the leaf is null', () {
      expect(notInNested(r'{"user": {"country": null}}'), isTrue);
    });

    test(r'$nin still excludes on a nested value', () {
      expect(notInNested(r'{"user": {"country": "RU"}}'), isFalse);
    });

    test(r'$in does not match when the parent object is absent', () {
      expect(
          eval(r'{"user.country": {"$in": ["RU", "CN"]}}',
              r'{"unrelated": "x"}'),
          isFalse);
    });
  });

  group('logical operators around membership', () {
    /// `$not` re-enters the same operator evaluation, so a double negation has
    /// to land on the exact inverse of the direct operator rather than on a
    /// shared false.
    test(r'$not of $in matches when attribute is absent', () {
      expect(
          eval(r'{"country": {"$not": {"$in": ["RU", "CN"]}}}',
              r'{"unrelated": "x"}'),
          isTrue);
    });

    test(r'$not of $nin does not match when attribute is absent', () {
      expect(
          eval(r'{"country": {"$not": {"$nin": ["RU", "CN"]}}}',
              r'{"unrelated": "x"}'),
          isFalse);
    });

    test(r'$or matches on the exclusion branch while the attribute is absent',
        () {
      const condition =
          r'{"$or": [{"country": {"$nin": ["RU", "CN"]}}, {"plan": "pro"}]}';
      expect(eval(condition, r'{"unrelated": "x"}'), isTrue);
      expect(eval(condition, r'{"country": "RU"}'), isFalse);
      expect(eval(condition, r'{"country": "RU", "plan": "pro"}'), isTrue);
    });

    test(r'$nor negates the exclusion while the attribute is absent', () {
      const condition = r'{"$nor": [{"country": {"$nin": ["RU", "CN"]}}]}';
      expect(eval(condition, r'{"unrelated": "x"}'), isFalse);
      expect(eval(condition, r'{"country": "RU"}'), isTrue);
    });

    /// `$exists: false` is the explicit way to target absence. Pairing it with
    /// `$nin` must stay consistent: both halves hold for a user without the
    /// attribute.
    test(r'$exists: false pairs consistently with $nin', () {
      const condition =
          r'{"country": {"$exists": false, "$nin": ["RU", "CN"]}}';
      expect(eval(condition, r'{"unrelated": "x"}'), isTrue);
      expect(eval(condition, r'{"country": "US"}'), isFalse);
    });
  });

  group('edge lists and value types', () {
    /// Nothing is a member of the empty list, so `$nin` holds for every input
    /// and `$in` for none — including the absent and null cases, where the
    /// answer must not come from a different branch.
    test(r'$nin an empty list always matches', () {
      expect(eval(r'{"country": {"$nin": []}}', r'{"unrelated": "x"}'), isTrue);
      expect(eval(r'{"country": {"$nin": []}}', r'{"country": null}'), isTrue);
      expect(eval(r'{"country": {"$nin": []}}', r'{"country": "RU"}'), isTrue);
    });

    test(r'$in an empty list never matches', () {
      expect(eval(r'{"country": {"$in": []}}', r'{"unrelated": "x"}'), isFalse);
      expect(eval(r'{"country": {"$in": []}}', r'{"country": null}'), isFalse);
      expect(eval(r'{"country": {"$in": []}}', r'{"country": "RU"}'), isFalse);
    });

    /// `null` is a legitimate list member, not a sentinel for absence. A user
    /// without the attribute is in `[null, "RU"]`, exactly as the reference SDK
    /// has it — `getPath` there also collapses a missing path to `null`
    /// (`mongrule.ts`), so `expected.includes(null)` matches.
    ///
    /// This is why the absent-attribute behaviour must keep coming from the
    /// membership check rather than from an early return on null:
    /// short-circuiting `$nin` to true whenever the attribute is null would
    /// invert both cases below and silently diverge from the other SDKs.
    test('null is a member of a list that contains it', () {
      expect(eval(r'{"country": {"$in": [null, "RU"]}}', r'{"country": null}'),
          isTrue);
      expect(eval(r'{"country": {"$in": [null, "RU"]}}', r'{"unrelated": "x"}'),
          isTrue);
      expect(eval(r'{"country": {"$nin": [null, "RU"]}}', r'{"country": null}'),
          isFalse);
      expect(
          eval(r'{"country": {"$nin": [null, "RU"]}}', r'{"unrelated": "x"}'),
          isFalse);
    });

    /// The rule is about membership, not about strings — numbers and booleans
    /// behave the same.
    test(r'$nin matches an absent numeric attribute', () {
      expect(
          eval(r'{"tier": {"$nin": [1, 2]}}', r'{"unrelated": "x"}'), isTrue);
      expect(eval(r'{"tier": {"$nin": [1, 2]}}', r'{"tier": null}'), isTrue);
      expect(eval(r'{"tier": {"$nin": [1, 2]}}', r'{"tier": 1}'), isFalse);
      expect(eval(r'{"tier": {"$nin": [1, 2]}}', r'{"tier": 3}'), isTrue);
    });

    test(r'$nin matches an absent boolean attribute', () {
      expect(
          eval(r'{"beta": {"$nin": [true]}}', r'{"unrelated": "x"}'), isTrue);
      expect(eval(r'{"beta": {"$nin": [true]}}', r'{"beta": true}'), isFalse);
      expect(eval(r'{"beta": {"$nin": [true]}}', r'{"beta": false}'), isTrue);
    });

    test(r'$elemMatch does not match when attribute is absent', () {
      expect(
          eval(
              r'{"tags": {"$elemMatch": {"$eq": "a"}}}', r'{"unrelated": "x"}'),
          isFalse);
    });

    test(r'$size does not match when attribute is absent', () {
      expect(eval(r'{"tags": {"$size": 0}}', r'{"unrelated": "x"}'), isFalse);
    });
  });
}
