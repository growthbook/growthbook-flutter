import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

import '../Helper/gb_test_helper.dart';

/// Spec sections run by this SDK's tests, and the test that runs each one.
const _runSections = {
  'evalCondition': 'gb_condition_test.dart',
  'hash': 'gb_utils_test.dart',
  'getBucketRange': 'gb_utils_test.dart',
  'feature': 'gb_feature_value_test.dart',
  'run': 'gb_experiment_run_test.dart',
  'chooseVariation': 'gb_utils_test.dart',
  'getQueryStringOverride': 'spec_coverage_test.dart',
  'inNamespace': 'gb_utils_test.dart',
  'getEqualWeights': 'gb_utils_test.dart',
  'decrypt': 'gb_utils_test.dart',
  'stickyBucket': 'gb_sticky_bucketing_feature_test.dart',
  'savedGroupReferencesV2.evalCondition':
      'gb_saved_group_references_v2_test.dart',
  'savedGroupReferencesV2.feature': 'gb_saved_group_references_v2_test.dart',
  'savedGroupReferencesV2.run': 'gb_saved_group_references_v2_test.dart',
};

/// Spec sections this SDK doesn't run, and why.
const _excludedSections = {
  'pruneCondition': 'The payload reduction methods (pruneCondition, '
      'reducePayload) are not implemented for client SDKs to start with',
  'reducePayload': 'The payload reduction methods (pruneCondition, '
      'reducePayload) are not implemented for client SDKs to start with',
  'urlRedirect': 'URL redirects are a browser feature this SDK lacks',
  'contextualBandit': 'This SDK does not support contextual bandits yet',
  'savedGroupReferencesRemote.evalCondition':
      'Remote saved groups (\$savedGroup) are not implemented yet',
  'savedGroupReferencesRemote.feature':
      'Remote saved groups (\$savedGroup) are not implemented yet',
};

/// Every case section in the spec, with nested sections as `parent.child`.
List<String> _specSections() {
  final sections = <String>[];
  (GBTestHelper.testData as Map).forEach((key, value) {
    if (value is List) {
      sections.add(key);
    } else if (value is Map) {
      for (final child in value.keys) {
        sections.add('$key.$child');
      }
    }
  });
  return sections;
}

void main() {
  group('Spec coverage', () {
    test('every spec section is run or explicitly excluded', () {
      final unaccounted = _specSections()
          .where((s) =>
              !_runSections.containsKey(s) && !_excludedSections.containsKey(s))
          .toList();
      expect(unaccounted, isEmpty,
          reason: 'Add new spec sections to _runSections or _excludedSections');
    });

    test('every listed section exists in the spec', () {
      final sections = _specSections().toSet();
      final stale = [..._runSections.keys, ..._excludedSections.keys]
          .where((s) => !sections.contains(s))
          .toList();
      expect(stale, isEmpty);
    });

    test('getQueryStringOverride', () {
      final failed = <String>[];
      for (final item in GBTestHelper.getQueryStringOverrideData()) {
        final result =
            GBUtils.getQueryStringOverride(item[1], item[2], item[3] as int);
        if (result != item[4]) {
          failed.add('${item[0]}: expected ${item[4]}, got $result');
        }
      }
      expect(failed, isEmpty);
    });
  });
}
