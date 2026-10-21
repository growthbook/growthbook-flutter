import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

import '../Helper/gb_test_helper.dart';

/// Conformance suite runner for the shared `contextualBandit` cases embedded
/// in `test_cases/test_case.dart`. Each case is a 4-tuple:
/// `[name, contextInput, featureKey, expectedResult]`.
///
/// The comparison covers the fields that the spec pins down for bandit
/// evaluation: the resolved feature value, source, and the bandit metadata
/// (`leafId`, `variationWeights`, `banditVersion`) surfaced on the
/// experiment result. Fields the spec does not constrain for these cases
/// (e.g. the exact bucket float) are intentionally left uncompared to avoid
/// coupling the tests to internal hashing details.
void main() {
  group('Contextual bandit conformance', () {
    late final List cases;
    setUpAll(() {
      cases = GBTestHelper.getContextualBanditData();
    });

    test('all cases pass', () {
      final failed = <String>[];
      final passed = <String>[];

      for (final raw in cases) {
        final item = raw as List;
        final name = item[0] as String;
        final input = item[1] as Map<String, dynamic>;
        final featureKey = item[2] as String;
        final expectedRaw = item[3] as Map<String, dynamic>;

        final testContext = GBContextTest.fromMap(input);

        final gbContext = GBContext(
          enabled: testContext.enabled,
          qaMode: testContext.qaMode,
          attributes: (testContext.attributes as Map?)?.cast<String, dynamic>(),
          forcedVariation: testContext.forcedVariations,
          trackingCallBack: (_) {},
          backgroundSync: false,
          savedGroups: testContext.savedGroups,
          url: (testContext.url?.isEmpty ?? true) ? null : testContext.url,
          contextualBandits: testContext.contextualBandits,
        );
        gbContext.features = testContext.features;

        final evalContext = GBUtils.initializeEvalContext(gbContext, null);
        final result =
            FeatureEvaluator().evaluateFeature(evalContext, featureKey);

        final diffs = _diff(name: name, expected: expectedRaw, actual: result);
        if (diffs.isEmpty) {
          passed.add(name);
        } else {
          failed.add('$name\n  - ${diffs.join('\n  - ')}');
        }
      }

      if (failed.isNotEmpty) {
        fail(
          '${failed.length}/${cases.length} bandit cases failed:\n\n'
          '${failed.join('\n\n')}',
        );
      }
      expect(passed.length, cases.length);
    });
  });
}

/// Returns a list of human-readable mismatches between the expected result
/// (from the shared cases) and the actual [GBFeatureResult]. An empty list
/// means the case passed.
List<String> _diff({
  required String name,
  required Map<String, dynamic> expected,
  required GBFeatureResult actual,
}) {
  final diffs = <String>[];

  final expectedValue = expected['value'];
  if (!_deepEquals(actual.value, expectedValue)) {
    diffs.add('value: expected $expectedValue, got ${actual.value}');
  }

  final expectedSource = expected['source'];
  if (expectedSource != null && actual.source?.name != expectedSource) {
    diffs.add('source: expected $expectedSource, got ${actual.source?.name}');
  }

  final expectedOn = expected['on'];
  if (expectedOn != null && actual.on != expectedOn) {
    diffs.add('on: expected $expectedOn, got ${actual.on}');
  }

  final expectedExperiment = expected['experiment'] as Map<String, dynamic>?;
  final expectedResult = expected['experimentResult'] as Map<String, dynamic>?;

  // When the case expects a bandit-triggered experiment, verify the bandit
  // metadata that the SDK is required to surface.
  if (expectedResult != null) {
    final ar = actual.experimentResult;
    if (ar == null) {
      diffs.add('experimentResult: expected present, got null');
    } else {
      _checkInt(diffs, 'experimentResult.leafId', expectedResult['leafId'],
          ar.leafId);
      _checkInt(diffs, 'experimentResult.banditVersion',
          expectedResult['banditVersion'], ar.banditVersion);
      _checkWeights(diffs, 'experimentResult.variationWeights',
          expectedResult['variationWeights'], ar.variationWeights);
      _checkString(diffs, 'experimentResult.key',
          expectedResult['key']?.toString(), ar.key);
      _checkInt(diffs, 'experimentResult.variationId',
          expectedResult['variationId'], ar.variationID);
      _checkBool(diffs, 'experimentResult.inExperiment',
          expectedResult['inExperiment'], ar.inExperiment);
    }
  }

  // Cross-check that experiment.contextualBandit (if the case pins it) lines
  // up with the same values on the result — this catches "attached but not
  // copied to result" regressions.
  final expectedCB =
      expectedExperiment?['contextualBandit'] as Map<String, dynamic>?;
  if (expectedCB != null && actual.experiment != null) {
    final cb = actual.experiment!.contextualBandit;
    if (cb == null) {
      diffs.add('experiment.contextualBandit: expected present, got null');
    } else {
      _checkInt(diffs, 'experiment.contextualBandit.leafId',
          expectedCB['leafId'], cb.leafId);
      _checkInt(diffs, 'experiment.contextualBandit.banditVersion',
          expectedCB['banditVersion'], cb.banditVersion);
      _checkWeights(diffs, 'experiment.contextualBandit.variationWeights',
          expectedCB['variationWeights'], cb.variationWeights);
    }
  }

  return diffs;
}

bool _deepEquals(dynamic a, dynamic b) {
  if (a == b) return true;
  if (a is num && b is num) return a.toDouble() == b.toDouble();
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!_deepEquals(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return false;
}

void _checkInt(List<String> diffs, String path, dynamic expected, int? actual) {
  if (expected == null) return; // spec doesn't pin this — skip
  if (expected != actual) {
    diffs.add('$path: expected $expected, got $actual');
  }
}

void _checkBool(
    List<String> diffs, String path, dynamic expected, bool? actual) {
  if (expected == null) return;
  if (expected != actual) {
    diffs.add('$path: expected $expected, got $actual');
  }
}

void _checkString(
    List<String> diffs, String path, String? expected, String? actual) {
  if (expected == null) return;
  if (expected != actual) {
    diffs.add('$path: expected $expected, got $actual');
  }
}

void _checkWeights(
    List<String> diffs, String path, dynamic expected, List<double>? actual) {
  if (expected == null) return;
  if (actual == null) {
    diffs.add('$path: expected $expected, got null');
    return;
  }
  final expectedList =
      (expected as List).map((e) => (e as num).toDouble()).toList();
  if (expectedList.length != actual.length) {
    diffs.add(
        '$path: expected length ${expectedList.length}, got ${actual.length}');
    return;
  }
  for (var i = 0; i < expectedList.length; i++) {
    if ((expectedList[i] - actual[i]).abs() > 1e-9) {
      diffs.add('$path[$i]: expected ${expectedList[i]}, got ${actual[i]}');
    }
  }
}
