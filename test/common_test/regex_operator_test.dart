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
  });
}

bool eval(String condition, String attributes) =>
    GBConditionEvaluator().isEvalCondition(
      jsonDecode(attributes) as Map<String, dynamic>,
      jsonDecode(condition),
      null,
    );
