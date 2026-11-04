import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

/// Covers experiments that reach the user through a feature rule rather than a
/// direct `run(...)` call.
///
/// `FeatureEvaluator` resolves those itself, so before the evaluation-context
/// sink the SDK never saw them: `getAllResults()` stayed empty and subscribers
/// were never notified, even though the tracking callback fired. In practice
/// most experiments arrive this way, which made `getAllResults()` close to
/// useless for the "which experiments is this user in" view it exists for.
void main() {
  group('GrowthBookSDK — feature-triggered experiments', () {
    const testApiKey = '<API_KEY>';
    const testHostURL = 'https://example.growthbook.io';
    final cachingManager = CachingManager();

    Future<GrowthBookSDK> buildSdk({
      Map<String, dynamic>? features,
      _StaticPayloadClient? client,
      Map<String, dynamic>? attributes,
      TrackingCallBack? trackingCallBack,
    }) {
      return GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attributes ?? {'id': 'user-1'},
        client: client ?? _StaticPayloadClient(features!),
        growthBookTrackingCallBack: trackingCallBack ?? (_) {},
        backgroundSync: false,
      ).initialize();
    }

    tearDown(() {
      cachingManager.clearCache();
    });

    /// A feature whose only rule runs [experimentKey] as an experiment and
    /// serves the winning variation as the feature value.
    Map<String, dynamic> featureRunning(String experimentKey) => {
          'defaultValue': 'control',
          'rules': [
            {
              'key': experimentKey,
              'variations': ['control', 'treatment'],
              'weights': [0.5, 0.5],
              'hashAttribute': 'id',
            }
          ],
        };

    // -------------------------------------------------------------------------
    // getAllResults
    // -------------------------------------------------------------------------
    group('getAllResults', () {
      test('a feature-triggered experiment is present', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });

        final feature = sdk.feature('banner');

        expect(feature.source, GBFeatureSource.experiment);
        expect(sdk.getAllResults(), contains('banner-exp'));
      });

      test('the recorded result matches the one the feature resolved to',
          () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });

        final feature = sdk.feature('banner');
        final recorded = sdk.getAllResults()['banner-exp'];

        expect(recorded, isNotNull);
        expect(recorded!.variationID, feature.experimentResult?.variationID);
        expect(recorded.value, feature.value);
        expect(recorded.inExperiment, isTrue);
      });

      test('evalFeature records the same way feature does', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });

        sdk.evalFeature('banner');

        expect(sdk.getAllResults(), contains('banner-exp'));
      });

      test('direct run and feature-triggered results coexist', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });

        sdk.run(GBExperiment(key: 'direct-exp', variations: [0, 1]));
        sdk.feature('banner');

        final results = sdk.getAllResults();
        expect(results.keys, containsAll(['direct-exp', 'banner-exp']));
        expect(results.length, 2);
      });

      test('several feature rules each record their experiment', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
          'checkout': featureRunning('checkout-exp'),
        });

        sdk.feature('banner');
        sdk.feature('checkout');

        expect(sdk.getAllResults().keys,
            containsAll(['banner-exp', 'checkout-exp']));
      });

      test('a feature with no experiment rule records nothing', () async {
        final sdk = await buildSdk(features: {
          'plain': {'defaultValue': 'on'},
        });

        final feature = sdk.feature('plain');

        expect(feature.source, GBFeatureSource.defaultValue);
        expect(sdk.getAllResults(), isEmpty);
      });

      test('a user left out of the experiment is still recorded', () async {
        // Reported before the inExperiment check, the way the reference SDK
        // does it — "not in it" is part of the answer the accessor gives.
        final sdk = await buildSdk(features: {
          'banner': {
            'defaultValue': 'control',
            'rules': [
              {
                'key': 'excluded-exp',
                'condition': {'role': 'tester'},
                'variations': ['control', 'treatment'],
                'weights': [0.5, 0.5],
                'hashAttribute': 'id',
              }
            ],
          },
        });

        final feature = sdk.feature('banner');

        expect(feature.source, GBFeatureSource.defaultValue,
            reason: 'the condition must exclude this user');
        final recorded = sdk.getAllResults()['excluded-exp'];
        expect(recorded, isNotNull);
        expect(recorded!.inExperiment, isFalse);
      });

      test('repeated reads of the same feature keep a single entry', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });

        sdk.feature('banner');
        sdk.feature('banner');
        sdk.feature('banner');

        expect(sdk.getAllResults().length, 1);
      });

      test('an unchanged assignment still refreshes the recorded result',
          () async {
        // The assignment did not move, so subscribers are not notified — but
        // the accessor must not keep handing out the result built against the
        // previous payload.
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });

        sdk.feature('banner');
        final before = sdk.getAllResults()['banner-exp']!;

        // Same key, weights and hash attribute, so the user buckets into the
        // same variation index — only the values behind it change.
        sdk.context.features = {
          'banner': GBFeature.fromJson({
            'defaultValue': 'control',
            'rules': [
              {
                'key': 'banner-exp',
                'variations': ['control-v2', 'treatment-v2'],
                'weights': [0.5, 0.5],
                'hashAttribute': 'id',
              }
            ],
          }),
        };
        sdk.evalFeature('banner');

        final after = sdk.getAllResults()['banner-exp']!;
        expect(after.variationID, before.variationID,
            reason: 'the assignment itself must not have moved');
        expect(after.value, isNot(before.value));
        expect(after.value, endsWith('-v2'));
      });

      test('last write wins when a direct run collides with a feature rule',
          () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });

        // Force the direct run onto the other variation so the two results are
        // distinguishable.
        sdk.feature('banner');
        final viaFeature = sdk.getAllResults()['banner-exp']!.variationID;

        sdk.run(GBExperiment(
          key: 'banner-exp',
          variations: ['control', 'treatment'],
          force: viaFeature == 0 ? 1 : 0,
        ));

        expect(
            sdk.getAllResults()['banner-exp']!.variationID, isNot(viaFeature));
      });

      test('dispose clears the accumulated results', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });

        sdk.feature('banner');
        expect(sdk.getAllResults(), isNotEmpty);

        await sdk.dispose();

        expect(sdk.getAllResults(), isEmpty);
      });

      /// Clearing the results is not enough on its own: the sink stayed
      /// installed, so the next read filled them in again — and counted as a
      /// change, so subscribers belonging to widgets already torn down were
      /// notified too.
      test('an evaluation after dispose records nothing', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });
        final seen = <String>[];
        sdk.subscribe((experiment, _) => seen.add(experiment.key));

        sdk.feature('banner');
        await sdk.dispose();
        seen.clear();

        final result = sdk.feature('banner');

        expect(result.source, GBFeatureSource.experiment,
            reason: 'evaluation still answers, it just stops recording');
        expect(sdk.getAllResults(), isEmpty);
        expect(seen, isEmpty);
      });

      test('the returned map is a snapshot', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });

        sdk.feature('banner');
        sdk.getAllResults().clear();

        expect(sdk.getAllResults(), contains('banner-exp'));
      });
    });

    // -------------------------------------------------------------------------
    // subscribe
    // -------------------------------------------------------------------------
    group('subscribe', () {
      test('a subscriber receives a feature-triggered experiment', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });
        final seen = <String>[];
        sdk.subscribe((experiment, _) => seen.add(experiment.key));

        sdk.feature('banner');

        expect(seen, ['banner-exp']);
      });

      test('repeated reads of the same feature notify once', () async {
        // A feature rule is evaluated on every read, so without the change
        // filter one assignment becomes a stream of identical notifications.
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });
        var calls = 0;
        sdk.subscribe((_, __) => calls++);

        sdk.feature('banner');
        sdk.feature('banner');
        sdk.feature('banner');

        expect(calls, 1);
      });

      test('a changed assignment notifies again', () async {
        final sdk = await buildSdk(
          features: {
            'banner': {
              'defaultValue': 'control',
              'rules': [
                {
                  'key': 'banner-exp',
                  'condition': {'role': 'tester'},
                  'variations': ['control', 'treatment'],
                  'weights': [0.5, 0.5],
                  'hashAttribute': 'id',
                }
              ],
            },
          },
          attributes: {'id': 'user-1'},
        );
        final seen = <bool>[];
        sdk.subscribe((_, result) => seen.add(result.inExperiment));

        sdk.feature('banner');
        // Now the user matches the rule's condition, so participation flips.
        sdk.setAttributes({'id': 'user-1', 'role': 'tester'});
        sdk.feature('banner');

        expect(seen, [false, true]);
      });

      test('a subscriber installed after the first read still gets the change',
          () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
          'checkout': featureRunning('checkout-exp'),
        });

        sdk.feature('banner');

        final seen = <String>[];
        sdk.subscribe((experiment, _) => seen.add(experiment.key));
        sdk.feature('checkout');

        expect(seen, ['checkout-exp']);
      });

      test('a throwing subscriber does not break feature()', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });
        sdk.subscribe((_, __) => throw StateError('listener disposed'));

        final feature = sdk.feature('banner');

        expect(feature.source, GBFeatureSource.experiment);
      });

      test('a throwing subscriber does not stop the others', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });
        var reached = 0;
        sdk.subscribe((_, __) => throw StateError('listener disposed'));
        sdk.subscribe((_, __) => reached++);

        sdk.feature('banner');

        expect(reached, 1);
      });

      /// A one-shot listener is the ordinary case, and before this branch only
      /// `run()` could reach it. Iterating the live list threw
      /// ConcurrentModificationError straight out of `feature()`.
      test('a subscriber may unsubscribe from inside its own callback',
          () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
          'checkout': featureRunning('checkout-exp'),
        });
        final seen = <String>[];
        final other = <String>[];
        late final Function unsubscribe;
        unsubscribe = sdk.subscribe((experiment, _) {
          seen.add(experiment.key);
          unsubscribe();
        });
        sdk.subscribe((experiment, _) => other.add(experiment.key));

        expect(() => sdk.feature('banner'), returnsNormally);
        sdk.feature('checkout');

        expect(seen, ['banner-exp'], reason: 'it unsubscribed after the first');
        expect(other, ['banner-exp', 'checkout-exp'],
            reason: 'the second subscriber is unaffected');
      });
    });

    // -------------------------------------------------------------------------
    // Subscribers run outside the evaluation
    // -------------------------------------------------------------------------
    group('notification timing', () {
      /// Notifying from inside the evaluators meant a subscriber ran halfway
      /// through the rule loop, against the state the evaluation was using.
      /// Reading a second feature cleared `stackContext.evaluatedFeatures`, so
      /// the outer feature's prerequisite and cycle checks then saw the wrong
      /// stack.
      test(
          'a subscriber may read another feature without disturbing the one '
          'being evaluated', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
          'checkout': featureRunning('checkout-exp'),
        });
        sdk.subscribe((experiment, _) {
          if (experiment.key == 'banner-exp') sdk.isOn('checkout');
        });

        final result = sdk.feature('banner');

        expect(result.source, GBFeatureSource.experiment);
        expect(sdk.getAllResults().keys, containsAll(['banner-exp']));
      });

      /// Replacing the attributes rebuilds the evaluation context. Called
      /// mid-evaluation, the outer `feature()` then copied
      /// `stickyBucketAssignmentDocs` out of the replacement and dropped the
      /// assignment it had just written.
      test('a subscriber may change attributes without losing the assignment',
          () async {
        final sdk = await GBSDKBuilderApp(
          apiKey: testApiKey,
          hostURL: testHostURL,
          attributes: {'id': 'user-1'},
          client: _StaticPayloadClient({
            'banner': featureRunning('banner-exp'),
          }),
          growthBookTrackingCallBack: (_) {},
          backgroundSync: false,
        ).setStickyBucketService(InMemoryStickyBucketService()).initialize();
        // Nothing is bucketed yet, so the evaluation creates the map on the
        // user context it started with — the case a mid-evaluation rebuild
        // loses.
        sdk.context.stickyBucketAssignmentDocs = null;
        sdk.subscribe((_, __) => sdk.setAttributes({'id': 'user-2'}));

        sdk.feature('banner');

        expect(sdk.context.stickyBucketAssignmentDocs, isNotEmpty);
        expect(sdk.getAllResults(), contains('banner-exp'));
        expect(sdk.context.attributes, {'id': 'user-2'});
      });

      test('the result is recorded before subscribers are notified', () async {
        final sdk = await buildSdk(features: {
          'banner': featureRunning('banner-exp'),
        });
        Map<String, GBExperimentResult>? visible;
        sdk.subscribe((_, __) => visible = sdk.getAllResults());

        sdk.feature('banner');

        expect(visible, contains('banner-exp'));
      });
    });
  });
}

/// Serves a caller-supplied feature payload, so each test can describe exactly
/// the rules it needs instead of leaning on the shared mock response.
class _StaticPayloadClient extends BaseClient {
  _StaticPayloadClient(this.features);

  Map<String, dynamic> features;

  Map<String, dynamic> get _payload =>
      jsonDecode(jsonEncode({'status': 200, 'features': features}))
          as Map<String, dynamic>;

  @override
  Future<void> consumeGetRequest(
      String url, OnSuccess onSuccess, OnError onError) async {
    await onSuccess(_payload);
  }

  @override
  Future<void> consumePostRequest(String baseUrl, Map<String, dynamic> params,
      OnSuccess onSuccess, OnError onError) async {
    await onSuccess(_payload);
  }

  @override
  Future<void> consumeSseConnections(
      String url, OnSuccess onSuccess, OnError onError) async {
    await onSuccess(_payload);
  }
}
