import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// The same `$nin` exclusion driven through a real feature rule rather than the
/// condition evaluator alone.
///
/// `membership_operator_test.dart` pins the operator; this pins the symptom
/// that made it worth fixing. A rule whose condition evaluates false is
/// skipped, so the feature silently falls through to its default — "serve
/// everyone except RU/CN" turns into "serve nobody" with no error anywhere.
/// Going through the feature evaluator also covers the conversion the
/// condition-level tests bypass: rule conditions are parsed from JSON into
/// `GBFeatureRule`, so a regression could live in the conversion rather than
/// in the operator.
///
/// Ported from the Kotlin SDK's `MembershipOperatorFeatureRuleTests`.
void main() {
  const featureKey = 'my_flag';
  const on = 'ON';
  const off = 'OFF';
  const countryExclusion = r'{"country": {"$nin": ["RU", "CN"]}}';

  GBFeatureResult evaluate(String condition, Map<String, dynamic> attributes) {
    final feature = GBFeature.fromJson({
      'defaultValue': off,
      'rules': [
        {
          'id': 'exclusion-rule',
          'condition': jsonDecode(condition),
          'force': on,
        },
      ],
    });

    final gbContext = GBContext(
      encryptionKey: null,
      enabled: true,
      qaMode: false,
      attributes: attributes,
      forcedVariation: const {},
      trackingCallBack: (_) {},
      backgroundSync: false,
    );
    gbContext.features = {featureKey: feature};

    final evaluationContext = GBUtils.initializeEvalContext(gbContext, null);
    return FeatureEvaluator().evaluateFeature(evaluationContext, featureKey);
  }

  dynamic exclusionValue(Map<String, dynamic> attributes) =>
      evaluate(countryExclusion, attributes).value;

  group(r'$nin exclusion through a feature rule', () {
    test('exclusion rule serves an unlisted country', () {
      expect(exclusionValue({'country': 'US'}), on);
    });

    test('exclusion rule does not serve a listed country', () {
      expect(exclusionValue({'country': 'RU'}), off);
    });

    test('exclusion rule serves a user whose attribute is null', () {
      expect(exclusionValue({'country': null}), on,
          reason: 'A null country is not RU or CN, so the exclusion rule '
              'must still apply');
    });

    test('exclusion rule serves a user without the attribute', () {
      expect(exclusionValue({}), on,
          reason: 'An attribute the app has not populated yet must not '
              'silently drop the user from the rule');
    });

    /// The failure mode is indistinguishable from an intentional default
    /// unless the source is checked: an unset attribute must still report the
    /// rule as the origin of the value, not `defaultValue`.
    test('exclusion rule is reported as the source for an absent attribute',
        () {
      final result = evaluate(countryExclusion, {});

      expect(result.source, GBFeatureSource.force);
      expect(result.ruleId, 'exclusion-rule');
    });

    test('default value is reported for a listed country', () {
      final result = evaluate(countryExclusion, {'country': 'RU'});

      expect(result.source, GBFeatureSource.defaultValue);
    });

    /// The shape reported in growthbook-swift#185: an exclusion on an attribute
    /// that only exists after login, ANDed with one that always exists. Logged
    /// out, the rule must still serve.
    test(
        'exclusion rule serves a logged-out user whose gated attribute '
        'is absent', () {
      const condition =
          r'{"plan": {"$nin": ["trial"]}, "country": {"$nin": ["RU", "CN"]}}';

      expect(evaluate(condition, {'country': 'US'}).value, on);
      expect(evaluate(condition, {'country': 'RU'}).value, off);
      expect(
          evaluate(condition, {'plan': 'trial', 'country': 'US'}).value, off);
    });
  });
}
