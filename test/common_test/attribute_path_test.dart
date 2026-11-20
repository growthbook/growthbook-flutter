import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Dot-separated attribute paths.
///
/// The walk used to skip a segment it could not descend into rather than stop,
/// so it returned the last value it reached: `user.id` against
/// `{"user": "u_1"}` answered `"u_1"`. A path therefore resolved to a value it
/// does not name, and a rule matched a user who has no such attribute —
/// silently, and in the direction that grants access rather than withholds it.
///
/// The shared spec fixtures exercise dotted paths only where the truncated
/// value happens to differ from the expected one (`{"address": 123}` is not
/// `"CA"` either way), so the whole corpus passed before the fix. These cases
/// pin the difference directly.
void main() {
  group('Attribute path', () {
    test('path stops at a scalar instead of returning it', () {
      expect(
        GBConditionEvaluator()
            .getPath(<String, dynamic>{'user': 'u_1'}, 'user.id'),
        isNull,
      );
    });

    test('path stops when it runs past the leaf', () {
      expect(
        GBConditionEvaluator().getPath(json(r'{"a": {"b": "x"}}'), 'a.b.c'),
        isNull,
      );
    });

    test('a valid path still resolves', () {
      expect(
        GBConditionEvaluator().getPath(
          json(r'{"pets": {"dog": {"name": "fido"}}}'),
          'pets.dog.name',
        ),
        'fido',
      );
    });

    /// The user has no `user.id`, so a rule naming it must not match on the
    /// value of `user`.
    test('truncated path does not satisfy an equality rule', () {
      expect(eval(r'{"user.id": "u_1"}', r'{"user": "u_1"}'), isFalse);
      expect(
        eval(r'{"user.id": "u_1"}', r'{"user": {"id": "u_1"}}'),
        isTrue,
        reason: 'control: the real path still matches',
      );
    });

    /// `$exists` reads the same walk, and this is the direction that matters: a
    /// truncated path used to report the attribute as present.
    test('truncated path does not exist', () {
      expect(
          eval(r'{"user.id": {"$exists": false}}', r'{"user": "u_1"}'), isTrue);
      expect(
          eval(r'{"user.id": {"$exists": true}}', r'{"user": "u_1"}'), isFalse);
    });

    /// A saved group names the attribute to test, and the name comes from the
    /// payload rather than from the rule, so a path that does not resolve must
    /// leave the user outside the group.
    test('truncated path does not place a user in a saved group', () {
      const groups =
          r'{"g": {"type": "list", "attributeKey": "user.id", "values": ["u_1"]}}';

      expect(
        eval(r'{"$savedGroup": {"id": "g"}}', r'{"user": "u_1"}',
            groups: groups),
        isFalse,
      );
      expect(
        eval(r'{"$savedGroup": {"id": "g"}}', r'{"user": {"id": "u_1"}}',
            groups: groups),
        isTrue,
        reason: 'control: the real path still places them inside',
      );
    });
  });
}

Map<String, dynamic> json(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

bool eval(String condition, String attributes, {String? groups}) =>
    GBConditionEvaluator().isEvalCondition(
      json(attributes),
      jsonDecode(condition),
      groups == null ? null : json(groups),
    );
