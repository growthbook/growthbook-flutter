import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// The `$regex` family against attributes that are not strings.
///
/// The attribute used to be required to be a string, so anything else failed
/// the match outright and a regex rule on an id or a build number sent as a
/// JSON number could never fire. The reference SDK hands the attribute to
/// `RegExp.prototype.test`, which converts it first.
///
/// That conversion is JavaScript's `String(value)`, and it is reproduced for
/// every value but one: an array is matched as its elements joined by commas
/// (`["internal", "beta"]` -> `"internal,beta"`), an object as
/// `"[object Object]"`.
///
/// `null` is the one conversion deliberately **not** reproduced, and the tests
/// below pin that decision so it is not "corrected" later by someone diffing
/// against `mongrule.ts`: it would render as the text `"null"`, which makes a
/// pattern like `ull` match a user who has no such attribute at all. That is an
/// artefact of JavaScript's string conversion, not targeting anyone meant to
/// express.
///
/// The shared spec fixtures (`cases.json`, spec 0.9.0) only ever match a string
/// pattern against a string attribute.
void main() {
  group('Regex operator', () {
    test('string attribute still matches', () {
      expect(
          eval(r'{"ua": {"$regex": "Android"}}', r'{"ua": "Android Mobile"}'),
          isTrue);
      expect(
          eval(r'{"ua": {"$regex": "Android"}}', r'{"ua": "Chrome Desktop"}'),
          isFalse);
    });

    test('case sensitivity is unchanged', () {
      expect(eval(r'{"ua": {"$regex": "android"}}', r'{"ua": "Android"}'),
          isFalse);
      expect(eval(r'{"ua": {"$regexi": "android"}}', r'{"ua": "Android"}'),
          isTrue);
    });

    test('negated variants are unchanged for strings', () {
      expect(eval(r'{"ua": {"$notRegex": "Android"}}', r'{"ua": "Chrome"}'),
          isTrue);
      expect(eval(r'{"ua": {"$notRegex": "Android"}}', r'{"ua": "Android"}'),
          isFalse);
      expect(eval(r'{"ua": {"$notRegexi": "android"}}', r'{"ua": "Chrome"}'),
          isTrue);
    });

    test('invalid pattern is not a match', () {
      expect(eval(r'{"ua": {"$regex": "("}}', r'{"ua": "anything"}'), isFalse);
    });

    test('numeric attribute is matched as text', () {
      expect(eval(r'{"id": {"$regex": "^12"}}', r'{"id": 123}'), isTrue);
      expect(eval(r'{"id": {"$regex": "^9"}}', r'{"id": 123}'), isFalse);
    });

    test('numeric attribute anchored whole match', () {
      expect(eval(r'{"id": {"$regex": "^123$"}}', r'{"id": 123}'), isTrue);
      expect(eval(r'{"id": {"$regex": "^12$"}}', r'{"id": 123}'), isFalse);
    });

    /// Same rendering rule as the version operators: an integral value carries
    /// no `.0`.
    test('integral decimal renders without fraction', () {
      expect(eval(r'{"id": {"$regex": "^10$"}}', r'{"id": 10.0}'), isTrue);
      expect(eval(r'{"id": {"$regex": "\\."}}', r'{"id": 10.0}'), isFalse);
    });

    test('non-integral decimal keeps its fraction', () {
      expect(eval(r'{"id": {"$regex": "^1\\.5$"}}', r'{"id": 1.5}'), isTrue);
    });

    test('negative number is matched as text', () {
      expect(eval(r'{"d": {"$regex": "^-3$"}}', r'{"d": -3}'), isTrue);
    });

    /// Ids beyond 2^53 must keep every digit. Normalising an integral attribute
    /// through a double first loses precision — `1234567890123456789` comes
    /// back as `1234567890123456768` — which would silently rewrite the text
    /// the pattern is matched against. Snowflake-style ids are exactly this
    /// size, so this is ordinary input, not an edge case.
    test('large integer id keeps every digit', () {
      expect(
        eval(
          r'{"id": {"$regex": "^1234567890123456789$"}}',
          r'{"id": 1234567890123456789}',
        ),
        isTrue,
      );
      expect(
        eval(
          r'{"id": {"$regex": "^1234567890123456768$"}}',
          r'{"id": 1234567890123456789}',
        ),
        isFalse,
      );
    });

    test('integer just past double precision keeps its value', () {
      expect(
        eval(
          r'{"id": {"$regex": "^9007199254740993$"}}',
          r'{"id": 9007199254740993}',
        ),
        isTrue,
      );
      expect(
        eval(
          r'{"id": {"$regex": "^9007199254740992$"}}',
          r'{"id": 9007199254740993}',
        ),
        isFalse,
      );
    });

    test('negated variant works for numbers', () {
      expect(eval(r'{"id": {"$notRegex": "^9"}}', r'{"id": 123}'), isTrue);
      expect(eval(r'{"id": {"$notRegex": "^12"}}', r'{"id": 123}'), isFalse);
    });

    test('boolean attribute is matched as text', () {
      expect(eval(r'{"b": {"$regex": "^true$"}}', r'{"b": true}'), isTrue);
      expect(eval(r'{"b": {"$regex": "^false$"}}', r'{"b": false}'), isTrue);
      expect(eval(r'{"b": {"$regex": "^true$"}}', r'{"b": false}'), isFalse);
    });

    test('boolean attribute is case-folded like any text', () {
      expect(eval(r'{"b": {"$regex": "TRUE"}}', r'{"b": true}'), isFalse);
      expect(eval(r'{"b": {"$regexi": "TRUE"}}', r'{"b": true}'), isTrue);
    });

    /// A pattern that matches the text `"null"` must not match a user without
    /// the attribute. The reference SDK answers true here; reproducing that
    /// would turn a typo into a targeting rule.
    test('absent attribute never matches', () {
      expect(eval(r'{"v": {"$regex": "ull"}}', r'{"other": "x"}'), isFalse);
      expect(eval(r'{"v": {"$regex": ".*"}}', r'{"other": "x"}'), isFalse);
    });

    test('null attribute never matches', () {
      expect(eval(r'{"v": {"$regex": "ull"}}', r'{"v": null}'), isFalse);
      expect(eval(r'{"v": {"$regex": ".*"}}', r'{"v": null}'), isFalse);
    });

    /// An array is matched as `Array.prototype.join` renders it, as in the
    /// reference SDK.
    test('array attribute is matched as joined text', () {
      expect(eval(r'{"v": {"$regex": "^1,2$"}}', r'{"v": [1, 2]}'), isTrue);
      expect(
        eval(r'{"v": {"$regex": "^internal"}}', r'{"v": ["internal", "beta"]}'),
        isTrue,
      );
      // The joined text starts with the first element only
      expect(
        eval(r'{"v": {"$regex": "^beta"}}', r'{"v": ["internal", "beta"]}'),
        isFalse,
      );
    });

    /// `join` renders a null element as empty and flattens a nested array into
    /// the same text.
    test('array elements render as JavaScript joins them', () {
      expect(
        eval(r'{"v": {"$regex": "^1,,a$"}}', r'{"v": [1, null, "a"]}'),
        isTrue,
      );
      expect(
        eval(r'{"v": {"$regex": "^1,2,3$"}}', r'{"v": [[1, 2], 3]}'),
        isTrue,
      );
      expect(
        eval(r'{"v": {"$regex": "^10,true$"}}', r'{"v": [10.0, true]}'),
        isTrue,
      );
    });

    test('object attribute is matched as object text', () {
      expect(
        eval(r'{"v": {"$regex": "^\\[object Object\\]$"}}',
            r'{"v": {"k": "v"}}'),
        isTrue,
      );
      expect(eval(r'{"v": {"$regex": "k"}}', r'{"v": {"k": "v"}}'), isFalse);
    });

    /// The pattern side stays strict: a non-string pattern is no match, as in
    /// the reference SDK.
    test('non-string pattern is not a match', () {
      expect(eval(r'{"v": {"$regex": 12}}', r'{"v": "123"}'), isFalse);
      expect(eval(r'{"v": {"$regex": 12}}', r'{"v": 123}'), isFalse);
    });

    /// An unusable *pattern* is the one case where the pair is deliberately not
    /// a negation, and the reference SDK agrees: it wraps the match in a
    /// try/catch returning false for `$notRegex` too, and a non-string pattern
    /// throws on its way into the RegExp constructor. Nothing can be said about
    /// a rule whose pattern does not compile, so neither polarity claims
    /// anything.
    test('an unusable pattern fails both polarities', () {
      expect(eval(r'{"v": {"$notRegex": 12}}', r'{"v": "123"}'), isFalse);
      expect(eval(r'{"v": {"$notRegex": "("}}', r'{"v": "anything"}'), isFalse);
    });

    /// An absent or null attribute is the mirror image: it matches no pattern,
    /// so it does-not-match every pattern. Answering false for both made a rule
    /// written as "everyone without a corporate email" match nobody — the same
    /// self-contradiction as `$eq` / `$ne` and `$inGroup` / `$notInGroup`
    /// before they were fixed.
    ///
    /// The reference SDK arrives elsewhere by stringifying (an absent attribute
    /// is looked up as `null`, which becomes the text `"null"`), which the
    /// 'absent attribute never matches' test explains is not reproduced. These
    /// assertions pin the negation property, not that route.
    test('negated variants pass for an attribute with no text', () {
      expect(eval(r'{"v": {"$notRegex": "ull"}}', r'{"other": "x"}'), isTrue);
      expect(eval(r'{"v": {"$notRegex": ".*"}}', r'{"v": null}'), isTrue);
      expect(
        eval(r'{"v": {"$notRegexi": "ANYTHING"}}', r'{"other": "x"}'),
        isTrue,
      );
    });

    /// Array and object attributes reach the operator instead of being skipped
    /// by an attribute-shape branch, and both polarities agree on their text:
    /// "everyone whose tags do not start with internal" excludes a user tagged
    /// `internal`, as the reference SDK's `{"$not": {"$regex": ...}}` does.
    test('multi-value attributes reach the operator', () {
      const tags = r'{"v": ["internal", "beta"]}';
      expect(eval(r'{"v": {"$regex": "^internal"}}', tags), isTrue);
      expect(eval(r'{"v": {"$notRegex": "^internal"}}', tags), isFalse);
      expect(eval(r'{"v": {"$not": {"$regex": "^internal"}}}', tags), isFalse);
      expect(eval(r'{"v": {"$notRegex": "^beta"}}', tags), isTrue);

      expect(
          eval(r'{"v": {"$regex": "object"}}', r'{"v": {"k": "v"}}'), isTrue);
      expect(
        eval(r'{"v": {"$notRegex": "object"}}', r'{"v": {"k": "v"}}'),
        isFalse,
      );
    });
  });
}

bool eval(String condition, String attributes) =>
    GBConditionEvaluator().isEvalCondition(
      jsonDecode(attributes) as Map<String, dynamic>,
      jsonDecode(condition),
      null,
    );
