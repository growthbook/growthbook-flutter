import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// `$inGroup` / `$notInGroup` across every attribute shape.
///
/// Both operators used to be reachable only for a primitive attribute, so a
/// multi-value attribute such as `tags: ["a", "b"]` fell through to the
/// function's trailing false and *both* operators answered false for the same
/// input — they cannot both be right. In practice that means a rule written as
/// "everyone except this saved group" matched nobody, the same failure shape as
/// the `$nin` defect covered in `membership_operator_test.dart`. The reference
/// SDK dispatches both on the operator alone (`mongrule.ts`:
/// `isIn(actual, savedGroups[expected] || [])`), and `isIn` intersects when the
/// attribute is an array.
///
/// The shared spec fixtures carry saved-group cases for both polarities, but
/// every one of them uses a scalar attribute (`{"id": 1}`, `{"id": "2"}`), so
/// the array shape is only covered here.
///
/// A `savedGroups` entry may also be a `savedGroupReferencesV2` typed object
/// rather than a bare array, and these operators can only read the list
/// flavour of one. Everything else fails them both closed — the single input
/// shape where the pair is deliberately *not* a negation, so those cases assert
/// through [assertBothFailClosed] rather than [assertExactInverse].
///
/// Ported from the Kotlin SDK's `SavedGroupOperatorTests`.
void main() {
  const savedGroups =
      r'{"grp": ["a", "b"], "ids": [1, 2], "empty": [], "mixed": [1, "2", 3]}';

  /// `savedGroupReferencesV2` entries. `list` names `id` as its attribute while
  /// every condition below sits on `tag`, so a test that passes by reading the
  /// entry's attribute instead of the one the operator sits on is visible
  /// rather than accidentally right.
  const typedSavedGroups = r'''
    {
      "list": {"type": "list", "attributeKey": "id", "values": ["a", "b"]},
      "cond": {"type": "condition", "condition": {"plan": "pro"}},
      "noValues": {"type": "list", "attributeKey": "id"},
      "future": {"type": "segment", "values": ["a", "b"]},
      "broken": null
    }
  ''';

  bool eval(String condition, String attributes,
          [String groups = savedGroups]) =>
      GBConditionEvaluator().isEvalCondition(
        jsonDecode(attributes) as Map<String, dynamic>,
        jsonDecode(condition),
        jsonDecode(groups) as Map<String, dynamic>,
      );

  bool evalTyped(String condition, String attributes) =>
      eval(condition, attributes, typedSavedGroups);

  bool inGroup(String attributes) =>
      eval(r'{"tag": {"$inGroup": "grp"}}', attributes);

  bool notInGroup(String attributes) =>
      eval(r'{"tag": {"$notInGroup": "grp"}}', attributes);

  /// The pair must stay a true logical negation for every input. A shape that
  /// returns false from both is the signature of the operator never being
  /// reached at all.
  void assertExactInverse(String attributes, {required bool expectedInGroup}) {
    final member = inGroup(attributes);
    final notMember = notInGroup(attributes);

    expect(member != notMember, isTrue,
        reason: r'$inGroup and $notInGroup both returned '
            '$member for $attributes');
    expect(member, expectedInGroup,
        reason: '\$inGroup for $attributes should be $expectedInGroup');
  }

  /// The exception to [assertExactInverse]: an entry neither operator can read
  /// answers false for both. Reading it as an empty list instead would keep the
  /// pair a negation and pass every user through an exclusion rule, which is
  /// the failure worth guarding against.
  void assertBothFailClosed(String groupId, String attributes) {
    expect(evalTyped('{"tag": {"\$inGroup": "$groupId"}}', attributes), isFalse,
        reason: '\$inGroup should fail closed for `$groupId`');
    expect(
        evalTyped('{"tag": {"\$notInGroup": "$groupId"}}', attributes), isFalse,
        reason: '\$notInGroup should fail closed for `$groupId` — '
            'an empty list would pass everyone');
  }

  group(r'$inGroup / $notInGroup', () {
    test('array attribute overlapping the group is a member', () {
      assertExactInverse(r'{"tag": ["b", "z"]}', expectedInGroup: true);
    });

    test('array attribute not overlapping the group is not a member', () {
      assertExactInverse(r'{"tag": ["y", "z"]}', expectedInGroup: false);
    });

    test('array attribute matching the group entirely is a member', () {
      assertExactInverse(r'{"tag": ["a", "b"]}', expectedInGroup: true);
    });

    /// An empty attribute contains nothing, so it intersects nothing.
    test('empty array attribute is not a member', () {
      assertExactInverse(r'{"tag": []}', expectedInGroup: false);
    });

    test('array attribute works for numeric groups', () {
      expect(eval(r'{"id": {"$inGroup": "ids"}}', r'{"id": [2, 9]}'), isTrue);
      expect(
          eval(r'{"id": {"$notInGroup": "ids"}}', r'{"id": [2, 9]}'), isFalse);
      expect(eval(r'{"id": {"$inGroup": "ids"}}', r'{"id": [8, 9]}'), isFalse);
      expect(
          eval(r'{"id": {"$notInGroup": "ids"}}', r'{"id": [8, 9]}'), isTrue);
    });

    test('string attribute in the group', () {
      assertExactInverse(r'{"tag": "a"}', expectedInGroup: true);
    });

    test('string attribute outside the group', () {
      assertExactInverse(r'{"tag": "z"}', expectedInGroup: false);
    });

    test('numeric attribute in the group', () {
      expect(eval(r'{"id": {"$inGroup": "ids"}}', r'{"id": 1}'), isTrue);
      expect(eval(r'{"id": {"$notInGroup": "ids"}}', r'{"id": 1}'), isFalse);
    });

    /// Membership compares type as well as value: the string `"1"` is not the
    /// number `1`.
    ///
    /// The control assertion carries the weight. On its own a `false` for `"1"`
    /// proves nothing — a value simply absent from the group produces the same
    /// answer — so the same digits are checked with the right type first.
    test('type mismatch is not a member', () {
      expect(eval(r'{"id": {"$inGroup": "ids"}}', r'{"id": 1}'), isTrue,
          reason: 'control: the number 1 is a member of [1, 2]');
      expect(eval(r'{"id": {"$inGroup": "ids"}}', r'{"id": "1"}'), isFalse);
      expect(eval(r'{"id": {"$notInGroup": "ids"}}', r'{"id": "1"}'), isTrue);
    });

    /// The spec's `properly typed data` / `improperly typed data` pair, whose
    /// group holds both a string and numbers (`[1, "2", 3]`). Matching is per
    /// element, so the same digit answers differently depending on which type
    /// the group happens to store.
    test('mixed-type group matches element by element', () {
      expect(eval(r'{"id": {"$inGroup": "mixed"}}', r'{"id": "2"}'), isTrue);
      expect(eval(r'{"id": {"$inGroup": "mixed"}}', r'{"id": 2}'), isFalse);

      expect(eval(r'{"id": {"$inGroup": "mixed"}}', r'{"id": 3}'), isTrue);
      expect(eval(r'{"id": {"$inGroup": "mixed"}}', r'{"id": "3"}'), isFalse);
    });

    test('absent attribute is not a member', () {
      assertExactInverse(r'{"unrelated": "x"}', expectedInGroup: false);
    });

    test('null attribute is not a member', () {
      assertExactInverse(r'{"tag": null}', expectedInGroup: false);
    });

    /// An object cannot be a member of a group of scalars, but the negation
    /// must still hold.
    test('object attribute is not a member', () {
      assertExactInverse(r'{"tag": {"k": "a"}}', expectedInGroup: false);
    });

    test('unknown group id treats the group as empty', () {
      expect(eval(r'{"tag": {"$inGroup": "nope"}}', r'{"tag": "a"}'), isFalse);
      expect(
          eval(r'{"tag": {"$notInGroup": "nope"}}', r'{"tag": "a"}'), isTrue);
    });

    test('empty group has no members', () {
      expect(eval(r'{"tag": {"$inGroup": "empty"}}', r'{"tag": "a"}'), isFalse);
      expect(
          eval(r'{"tag": {"$notInGroup": "empty"}}', r'{"tag": "a"}'), isTrue);
    });

    test('unknown group with an array attribute', () {
      expect(eval(r'{"tag": {"$inGroup": "nope"}}', r'{"tag": ["a", "b"]}'),
          isFalse);
      expect(eval(r'{"tag": {"$notInGroup": "nope"}}', r'{"tag": ["a", "b"]}'),
          isTrue);
    });
  });

  group(r'$inGroup / $notInGroup with savedGroupReferencesV2 entries', () {
    test('typed list entry resolves for both polarities', () {
      expect(
          evalTyped(r'{"tag": {"$inGroup": "list"}}', r'{"tag": "a"}'), isTrue);
      expect(evalTyped(r'{"tag": {"$notInGroup": "list"}}', r'{"tag": "a"}'),
          isFalse);

      expect(evalTyped(r'{"tag": {"$inGroup": "list"}}', r'{"tag": "z"}'),
          isFalse);
      expect(evalTyped(r'{"tag": {"$notInGroup": "list"}}', r'{"tag": "z"}'),
          isTrue);
    });

    /// A typed entry names its own attribute, but these operators do not read
    /// it: they take the attribute from the condition they sit on, as they
    /// always have. Only `$savedGroup`, which is not bound to an attribute at
    /// all, uses the entry's.
    test('typed list entry uses the attribute the operator sits on', () {
      expect(
          evalTyped(
              r'{"tag": {"$inGroup": "list"}}', r'{"tag": "a", "id": "z"}'),
          isTrue,
          reason: 'the condition sits on `tag`, so `tag` decides');
      expect(
          evalTyped(
              r'{"tag": {"$inGroup": "list"}}', r'{"tag": "z", "id": "a"}'),
          isFalse,
          reason: "reading the entry's `id` instead would wrongly pass");
    });

    /// The attribute is a member of the group's condition, which makes no
    /// difference here.
    test('condition entry fails both operators closed', () {
      assertBothFailClosed('cond', r'{"tag": "a", "plan": "pro"}');
    });

    test('unknown entry type fails both operators closed', () {
      assertBothFailClosed('future', r'{"tag": "a"}');
    });

    test('typed list entry without values fails both operators closed', () {
      assertBothFailClosed('noValues', r'{"tag": "a"}');
    });

    /// `{"broken": null}` is present in the map, so it is malformed rather than
    /// absent.
    test('malformed entry fails both operators closed', () {
      assertBothFailClosed('broken', r'{"tag": "a"}');
    });

    /// The one shape that keeps passing: an id absent from the map behaves like
    /// an empty group, so `$notInGroup` passes. Anchored here because the
    /// fail-closed rule above is one careless edit away from swallowing it.
    test('absent id still passes \$notInGroup beside typed entries', () {
      expect(evalTyped(r'{"tag": {"$inGroup": "nope"}}', r'{"tag": "a"}'),
          isFalse);
      expect(evalTyped(r'{"tag": {"$notInGroup": "nope"}}', r'{"tag": "a"}'),
          isTrue);
    });
  });

  /// The `attributeKey` override on a `$savedGroup` reference. The shared spec
  /// fixtures cover a string override and a non-string one, but not an
  /// explicit `null`.
  group('\$savedGroup attributeKey override', () {
    test('a string override replaces the entry\'s own attribute', () {
      expect(
          evalTyped(
              r'{"$savedGroup": {"id": "list", "attributeKey": "backup"}}',
              r'{"id": "z", "backup": "a"}'),
          isTrue);
    });

    test('an absent override falls back to the entry\'s own attribute', () {
      expect(evalTyped(r'{"$savedGroup": {"id": "list"}}', r'{"id": "a"}'),
          isTrue);
    });

    /// The reference SDK checks `attributeKey !== undefined`, which is true
    /// for `null`, and then rejects it as not a string. Falling back to the
    /// entry's own attribute instead would test a different population than
    /// the payload asked for.
    test('an explicit null override fails closed', () {
      expect(
          evalTyped(r'{"$savedGroup": {"id": "list", "attributeKey": null}}',
              r'{"id": "a"}'),
          isFalse);
    });
  });
}
