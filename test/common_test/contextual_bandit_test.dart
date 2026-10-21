import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/global_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/options.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/user_context.dart';

/// Coverage for the SDK-side contextual-bandit flow ported from Java PR #79.
///
/// These tests build an [EvaluationContext] directly rather than going through
/// [GBSDKBuilderApp] so we can exercise the evaluator without a live network
/// mock — the payload plumbing (`FeaturedDataModel.contextualBandits`
/// → `GBContext.contextualBandits` → `GlobalContext.contextualBandits`) is
/// covered separately in the SDK builder tests.
void main() {
  group('contextual bandit evaluation', () {
    // Two-variation bandit: control (index 0) vs treatment (index 1).
    // Weights below force every bucketed user onto index 1 (treatment), so we
    // can assert on the exposed value without also asserting the hash bucket.
    Map<String, dynamic> banditPayload({int version = 3}) => {
          'bandit-1': {
            'banditVersion': version,
            'contexts': [
              {
                'leafId': 0,
                'condition': {'country': 'US'},
                'weights': [1.0, 0.0],
              },
              {
                'leafId': 1,
                'condition': {'country': 'CA'},
                'weights': [0.0, 1.0],
              },
            ],
          },
        };

    GBFeature banditFeature() => GBFeature(
          defaultValue: 'default',
          rules: [
            GBFeatureRule(
              id: 'banner-bandit',
              contextualBanditRef: 'bandit-1',
              contextualVariations: ['control', 'treatment'],
              hashAttribute: 'id',
              coverage: 1.0,
            ),
          ],
        );

    EvaluationContext buildContext({
      required Map<String, dynamic> attributes,
      Map<String, dynamic>? contextualBandits,
      GBFeatures? features,
    }) {
      final options = Options(
        enabled: true,
        isQaMode: false,
        isCacheDisabled: true,
        trackingCallBackWithUser: (_) {},
      );
      final global = GlobalContext(
        features: features ?? {'banner': banditFeature()},
      );
      global.contextualBandits = contextualBandits;
      final user = UserContext(attributes: attributes);
      return EvaluationContext(
        globalContext: global,
        userContext: user,
        stackContext: StackContext(),
        options: options,
      );
    }

    test('matching leaf applies its weights and records bandit metadata', () {
      final ctx = buildContext(
        attributes: {'id': 'u1', 'country': 'CA'},
        contextualBandits: banditPayload(),
      );

      final result = FeatureEvaluator().evaluateFeature(ctx, 'banner');
      final exp = result.experimentResult!;

      expect(result.value, 'treatment');
      expect(exp.inExperiment, isTrue);
      expect(exp.leafId, 1);
      expect(exp.banditVersion, 3);
      expect(exp.variationWeights, [0.0, 1.0]);
    });

    test('no matching leaf falls back to leafId -1 with equal weights', () {
      // country=FR matches neither leaf — evaluator should record the
      // fallback marker and keep the aggregate/equal weights.
      final ctx = buildContext(
        attributes: {'id': 'u1', 'country': 'FR'},
        contextualBandits: banditPayload(),
      );

      final result = FeatureEvaluator().evaluateFeature(ctx, 'banner');
      final exp = result.experimentResult!;

      expect(exp.inExperiment, isTrue);
      expect(exp.leafId, kContextualBanditFallbackLeafId);
      expect(exp.variationWeights, [0.5, 0.5]);
      expect(exp.banditVersion, 3);
    });

    test('missing ref in payload leaves the experiment without bandit metadata',
        () {
      final ctx = buildContext(
        attributes: {'id': 'u1', 'country': 'CA'},
        contextualBandits: const {}, // ref not present
      );

      final result = FeatureEvaluator().evaluateFeature(ctx, 'banner');
      final exp = result.experimentResult!;

      // Experiment still runs (aggregate weights == equal weights here) but
      // there is no bandit selection to attribute the exposure to.
      expect(exp.inExperiment, isTrue);
      expect(exp.leafId, isNull);
      expect(exp.variationWeights, isNull);
      expect(exp.banditVersion, isNull);
    });

    test('first matching leaf wins even if a later leaf also matches', () {
      final firstMatchPayload = {
        'bandit-1': {
          'banditVersion': 7,
          'contexts': [
            {
              'leafId': 10,
              'condition': {'country': 'US'},
              'weights': [1.0, 0.0],
            },
            {
              'leafId': 20,
              'condition': {'country': 'US'}, // also matches
              'weights': [0.0, 1.0],
            },
          ],
        },
      };
      final ctx = buildContext(
        attributes: {'id': 'u1', 'country': 'US'},
        contextualBandits: firstMatchPayload,
      );

      final exp =
          FeatureEvaluator().evaluateFeature(ctx, 'banner').experimentResult!;

      expect(exp.leafId, 10);
      expect(exp.variationWeights, [1.0, 0.0]);
      expect(exp.banditVersion, 7);
    });

    test('malformed definition falls back to aggregate weights silently', () {
      // contexts entry has a bogus type — deserialization throws, evaluator
      // must swallow and treat as "no bandit for this ref".
      final malformed = {
        'bandit-1': {
          'banditVersion': 1,
          'contexts': 'not-a-list',
        },
      };
      final ctx = buildContext(
        attributes: {'id': 'u1', 'country': 'CA'},
        contextualBandits: malformed,
      );

      final exp =
          FeatureEvaluator().evaluateFeature(ctx, 'banner').experimentResult!;

      // No metadata on the result — behaves as if the ref were absent.
      expect(exp.leafId, isNull);
      expect(exp.variationWeights, isNull);
      expect(exp.banditVersion, isNull);
    });

    test(
        'contextualVariations is used even when contextualBanditRef is absent '
        '(graceful degradation shape)', () {
      // Rule with only contextualVariations set; older SDKs would skip because
      // rule.variations is null. New SDKs must pick up contextualVariations
      // and run the experiment normally without bandit metadata.
      final degradedFeature = GBFeature(
        defaultValue: 'default',
        rules: [
          GBFeatureRule(
            id: 'ctx-var-only',
            contextualVariations: ['control', 'treatment'],
            hashAttribute: 'id',
            coverage: 1.0,
          ),
        ],
      );
      final ctx = buildContext(
        attributes: {'id': 'u1'},
        features: {'banner': degradedFeature},
      );

      final result = FeatureEvaluator().evaluateFeature(ctx, 'banner');
      final exp = result.experimentResult!;

      expect(exp.inExperiment, isTrue);
      expect(exp.leafId, isNull); // no ref → no bandit metadata
      // Value comes from contextualVariations, not defaultValue.
      expect(['control', 'treatment'], contains(result.value));
    });

    test('user filtered out of experiment gets no bandit metadata leaked', () {
      // coverage=0 → nobody is in the experiment. Even though a leaf would
      // match, the evaluator must clear the bandit selection so a
      // non-bucketed exposure never carries bandit fields.
      final zeroCoverageFeature = GBFeature(
        defaultValue: 'default',
        rules: [
          GBFeatureRule(
            id: 'zero-coverage',
            contextualBanditRef: 'bandit-1',
            contextualVariations: ['control', 'treatment'],
            hashAttribute: 'id',
            coverage: 0.0,
          ),
        ],
      );
      final ctx = buildContext(
        attributes: {'id': 'u1', 'country': 'CA'},
        contextualBandits: banditPayload(),
        features: {'banner': zeroCoverageFeature},
      );

      final result = FeatureEvaluator().evaluateFeature(ctx, 'banner');
      // Rule was skipped → default value returned, no experiment result.
      expect(result.value, 'default');
      expect(result.experimentResult, isNull);
    });

    // The reported weights must be the ones the user was actually bucketed
    // with; the bandit learns from them. These cases mirror the Kotlin SDK.
    group('reported weights match the assignment', () {
      GBFeature featureWith(
              {List<double>? weights, List<List<double>>? ranges}) =>
          GBFeature(
            defaultValue: 'default',
            rules: [
              GBFeatureRule(
                id: 'banner-bandit',
                contextualBanditRef: 'bandit-1',
                contextualVariations: ['control', 'treatment'],
                hashAttribute: 'id',
                coverage: 1.0,
                weights: weights,
                ranges: ranges,
              ),
            ],
          );

      Map<String, dynamic> payloadWithLeaf(Map<String, dynamic> leaf) => {
            'bandit-1': {
              'banditVersion': 3,
              'contexts': [
                {
                  'condition': {'country': 'CA'},
                  ...leaf
                },
              ],
            },
          };

      GBExperimentResult evaluate(
          {required Map<String, dynamic> contextualBandits,
          GBFeature? feature}) {
        final ctx = buildContext(
          attributes: {'id': 'u1', 'country': 'CA'},
          contextualBandits: contextualBandits,
          features: {'banner': feature ?? banditFeature()},
        );
        return FeatureEvaluator()
            .evaluateFeature(ctx, 'banner')
            .experimentResult!;
      }

      test('explicit ranges bucket the user and report no bandit metadata', () {
        // The ranges send everyone to control; the matching leaf would send
        // everyone to treatment. Ranges win in the bucketer, so the leaf's
        // weights describe nothing that happened.
        final exp = evaluate(
          contextualBandits: banditPayload(),
          feature: featureWith(ranges: [
            [0.0, 1.0],
            [1.0, 1.0],
          ]),
        );

        expect(exp.value, 'control');
        expect(exp.leafId, isNull);
        expect(exp.variationWeights, isNull);
        expect(exp.banditVersion, isNull);
      });

      for (final entry in {
        'too few weights': [1.0],
        'weights not summing to 1': [0.6, 0.6],
        'a negative weight': [1.5, -0.5],
        'a non-finite weight': [double.nan, 1.0],
      }.entries) {
        test('a leaf with ${entry.key} falls back to the bucketed weights', () {
          final exp = evaluate(
            contextualBandits:
                payloadWithLeaf({'leafId': 1, 'weights': entry.value}),
          );

          expect(exp.leafId, kContextualBanditFallbackLeafId);
          expect(exp.variationWeights, [0.5, 0.5]);
        });
      }

      test('a leaf without a leafId falls back', () {
        final exp = evaluate(
          contextualBandits: payloadWithLeaf({
            'weights': [0.0, 1.0]
          }),
        );

        expect(exp.leafId, kContextualBanditFallbackLeafId);
        expect(exp.variationWeights, [0.5, 0.5]);
      });

      test(
          'the fallback reports equal weights when the rule weights are invalid',
          () {
        // No leaf matches FR; the rule's own weights would be replaced by the
        // bucketer, so equal weights are what actually applied.
        final ctx = buildContext(
          attributes: {'id': 'u1', 'country': 'FR'},
          contextualBandits: banditPayload(),
          features: {
            'banner': featureWith(weights: [0.7, 0.7])
          },
        );
        final exp =
            FeatureEvaluator().evaluateFeature(ctx, 'banner').experimentResult!;

        expect(exp.leafId, kContextualBanditFallbackLeafId);
        expect(exp.variationWeights, [0.5, 0.5]);
      });

      test('the fallback keeps valid rule weights', () {
        final ctx = buildContext(
          attributes: {'id': 'u1', 'country': 'FR'},
          contextualBandits: banditPayload(),
          features: {
            'banner': featureWith(weights: [0.2, 0.8])
          },
        );
        final exp =
            FeatureEvaluator().evaluateFeature(ctx, 'banner').experimentResult!;

        expect(exp.leafId, kContextualBanditFallbackLeafId);
        expect(exp.variationWeights, [0.2, 0.8]);
      });
    });
  });
}
