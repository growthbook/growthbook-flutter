import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/network_mock.dart';

void main() {
  group('GrowthBookSDK — attribute & variation management', () {
    const testApiKey = '<API_KEY>';
    const testHostURL = 'https://example.growthbook.io';
    const client = MockNetworkClient();
    final cachingManager = CachingManager();

    Future<GrowthBookSDK> buildSdk({Map<String, dynamic>? attributes}) async {
      return GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attributes ?? {'id': 'user-1'},
        client: client,
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
      ).initialize();
    }

    tearDown(() {
      cachingManager.clearCache();
    });

    // -------------------------------------------------------------------------
    // setAttributes
    // -------------------------------------------------------------------------
    group('setAttributes', () {
      test('updates context.attributes', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});
        sdk.setAttributes({'id': 'user-2', 'country': 'UA'});
        expect(sdk.context.attributes, {'id': 'user-2', 'country': 'UA'});
      });

      test('replaces previous attributes entirely', () async {
        final sdk =
            await buildSdk(attributes: {'id': 'user-1', 'plan': 'free'});
        sdk.setAttributes({'id': 'user-2'});
        expect(sdk.context.attributes?.containsKey('plan'), isFalse);
      });

      test('new attributes affect experiment bucketing', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});

        // Experiment with condition — only users with role == 'tester' pass
        final experiment = GBExperiment(
          key: 'attr-exp',
          variations: [0, 1],
          condition: {'role': 'tester'},
        );

        final before = sdk.run(experiment);
        expect(before.inExperiment, isFalse);

        sdk.setAttributes({'id': 'user-1', 'role': 'tester'});
        final after = sdk.run(experiment);
        expect(after.inExperiment, isTrue);
      });

      test('accepts empty attributes map', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});
        sdk.setAttributes({});
        expect(sdk.context.attributes, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // updateAttributes — shallow merge (parity with the JS/TS updateAttributes)
    // -------------------------------------------------------------------------
    group('updateAttributes', () {
      test('merges new attributes into the existing ones', () async {
        final sdk =
            await buildSdk(attributes: {'id': 'user-1', 'country': 'UA'});
        sdk.updateAttributes({'plan': 'pro'});
        expect(sdk.context.attributes,
            {'id': 'user-1', 'country': 'UA', 'plan': 'pro'});
      });

      test('overwrites existing keys and preserves untouched ones', () async {
        final sdk =
            await buildSdk(attributes: {'id': 'user-1', 'country': 'UA'});
        sdk.updateAttributes({'country': 'FR'});
        expect(sdk.context.attributes, {'id': 'user-1', 'country': 'FR'});
      });

      test('merges instead of replacing (unlike setAttributes)', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});
        sdk.setAttributes({'plan': 'pro'});
        sdk.updateAttributes({'id': 'user-2'});
        expect(sdk.context.attributes, {'plan': 'pro', 'id': 'user-2'});
      });

      test('empty map is a no-op', () async {
        final sdk =
            await buildSdk(attributes: {'id': 'user-1', 'country': 'UA'});
        sdk.updateAttributes({});
        expect(sdk.context.attributes, {'id': 'user-1', 'country': 'UA'});
      });

      test('stores a null value without removing the key', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1', 'plan': 'pro'});
        sdk.updateAttributes({'plan': null});
        expect(sdk.context.attributes, {'id': 'user-1', 'plan': null});
        expect(sdk.context.attributes?.containsKey('plan'), isTrue);
      });

      test('merge is shallow — a nested Map replaces the previous value',
          () async {
        final sdk = await buildSdk(attributes: {
          'account': {'age': 90, 'plan': 'pro'},
        });
        sdk.updateAttributes({
          'account': {'age': 10},
        });
        expect(sdk.context.attributes, {
          'account': {'age': 10},
        });
      });

      test('merged attributes affect experiment bucketing', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});

        // Only users with role == 'tester' pass the condition.
        final experiment = GBExperiment(
          key: 'attr-exp',
          variations: [0, 1],
          condition: {'role': 'tester'},
        );

        expect(sdk.run(experiment).inExperiment, isFalse);

        // The id must survive the merge, otherwise there is nothing to hash on.
        sdk.updateAttributes({'role': 'tester'});
        expect(sdk.context.attributes?['id'], 'user-1');
        expect(sdk.run(experiment).inExperiment, isTrue);
      });

      test('does not mutate the Map passed in by the caller', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});
        final incoming = <String, dynamic>{'plan': 'pro'};
        sdk.updateAttributes(incoming);
        expect(incoming, {'plan': 'pro'});
      });

      test('repeated updates accumulate', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});
        sdk.updateAttributes({'plan': 'pro'});
        sdk.updateAttributes({'country': 'UA'});
        sdk.updateAttributes({'plan': 'enterprise'});
        expect(sdk.context.attributes,
            {'id': 'user-1', 'plan': 'enterprise', 'country': 'UA'});
      });

      test('concurrent evaluations never observe a partially merged state',
          () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});
        sdk.context.features = {
          'flag': GBFeature(
            defaultValue: false,
            rules: [
              GBFeatureRule(
                condition: {'id': 'user-1', 'plan': 'pro', 'country': 'UA'},
                force: true,
              ),
            ],
          ),
        };

        // Interleave updates with evaluations: an evaluation must always see
        // either the pre-merge attributes or the fully merged ones.
        final observed = <Map<String, dynamic>>[];
        final evaluated = <bool>[];
        await Future.wait([
          for (var i = 0; i < 20; i++)
            Future<void>(() {
              sdk.updateAttributes({'plan': 'pro', 'country': 'UA'});
              observed.add({...?sdk.context.attributes});
            }),
          for (var i = 0; i < 20; i++)
            Future<void>(() => evaluated.add(sdk.isOn('flag'))),
        ]);

        for (final attributes in observed) {
          expect(attributes, {
            'id': 'user-1',
            'plan': 'pro',
            'country': 'UA',
          });
        }
        // The last evaluations run after every merge, so the rule must match.
        expect(evaluated.last, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // updateAttributesAsync
    // -------------------------------------------------------------------------
    group('updateAttributesAsync', () {
      test('merges the same way as updateAttributes', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});
        await sdk.updateAttributesAsync({'plan': 'pro'});
        expect(sdk.context.attributes, {'id': 'user-1', 'plan': 'pro'});
      });

      test('awaits the sticky bucket refresh before returning', () async {
        final svc = _TrackingStickyBucketService();
        final builder = GBSDKBuilderApp(
          apiKey: testApiKey,
          hostURL: testHostURL,
          attributes: {'id': 'user-1'},
          client: client,
          growthBookTrackingCallBack: (_) {},
          backgroundSync: false,
        )..setStickyBucketService(svc);
        final sdk = await builder.initialize();

        final beforeCalls = svc.getAllAssignmentsCalls;
        // No artificial delay — the refresh must already have happened.
        await sdk.updateAttributesAsync({'id': 'user-2'});
        expect(svc.getAllAssignmentsCalls, greaterThan(beforeCalls));
      });
    });

    // -------------------------------------------------------------------------
    // setAttributeOverrides
    // -------------------------------------------------------------------------
    group('setAttributeOverrides', () {
      test('stores decoded overrides accessible via getter', () async {
        final sdk = await buildSdk();
        sdk.setAttributeOverrides('{"premium": true, "country": "UA"}');
        expect(sdk.attributeOverrides['premium'], true);
        expect(sdk.attributeOverrides['country'], 'UA');
      });

      test('attributeOverrides getter returns empty map initially', () async {
        final sdk = await buildSdk();
        expect(sdk.attributeOverrides, isEmpty);
      });

      test('replaces previous overrides on subsequent calls', () async {
        final sdk = await buildSdk();
        sdk.setAttributeOverrides('{"key": "first"}');
        sdk.setAttributeOverrides('{"key": "second"}');
        expect(sdk.attributeOverrides['key'], 'second');
      });

      test('accepts empty JSON object', () async {
        final sdk = await buildSdk();
        sdk.setAttributeOverrides('{}');
        expect(sdk.attributeOverrides, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // setForcedVariations
    // -------------------------------------------------------------------------
    group('setForcedVariations', () {
      test('updates context.forcedVariation', () async {
        final sdk = await buildSdk();
        sdk.setForcedVariations({'exp-key': 1});
        expect(sdk.context.forcedVariation?['exp-key'], 1);
      });

      test('forces specific variation index when running experiment', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});
        sdk.setForcedVariations({'forced-exp': 2});

        final result = sdk.run(GBExperiment(
          key: 'forced-exp',
          variations: [0, 1, 2],
        ));

        expect(result.variationID, 2);
      });

      test('overrides previous forced variations', () async {
        final sdk = await buildSdk(attributes: {'id': 'user-1'});
        sdk.setForcedVariations({'exp-x': 1});
        sdk.setForcedVariations({'exp-x': 0});

        final result = sdk.run(GBExperiment(
          key: 'exp-x',
          variations: [0, 1],
        ));

        expect(result.variationID, 0);
      });

      test('accepts empty map to clear forced variations', () async {
        final sdk = await buildSdk();
        sdk.setForcedVariations({'exp-clear': 1});
        sdk.setForcedVariations({});
        expect(sdk.context.forcedVariation, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // setForcedFeatures
    // -------------------------------------------------------------------------
    group('setForcedFeatures', () {
      test('can be called without error', () async {
        final sdk = await buildSdk();
        expect(
          () => sdk.setForcedFeatures([
            {'feature-a': 0},
            {'feature-b': 1},
          ]),
          returnsNormally,
        );
      });

      test('accepts empty list', () async {
        final sdk = await buildSdk();
        expect(() => sdk.setForcedFeatures([]), returnsNormally);
      });
    });

    // -------------------------------------------------------------------------
    // Sticky bucket refresh triggered by setForcedVariations and
    // setEncryptedFeatures (regression for Trello "Checking sticky bucket issue")
    // -------------------------------------------------------------------------
    group('sticky bucket refresh on additional setters', () {
      Future<GrowthBookSDK> buildSdkWithStickyBucket(
          _TrackingStickyBucketService svc) async {
        final builder = GBSDKBuilderApp(
          apiKey: testApiKey,
          hostURL: testHostURL,
          attributes: {'id': 'user-1'},
          client: client,
          growthBookTrackingCallBack: (_) {},
          backgroundSync: false,
        )..setStickyBucketService(svc);
        return builder.initialize();
      }

      test('setForcedVariations triggers sticky bucket refresh', () async {
        final svc = _TrackingStickyBucketService();
        final sdk = await buildSdkWithStickyBucket(svc);

        final beforeCalls = svc.getAllAssignmentsCalls;
        sdk.setForcedVariations({'exp-1': 1});
        // Give the fire-and-forget refresh a chance to run.
        await Future<void>.delayed(Duration.zero);

        expect(svc.getAllAssignmentsCalls, greaterThan(beforeCalls));
      });

      test('setEncryptedFeatures triggers sticky bucket refresh', () async {
        final svc = _TrackingStickyBucketService();
        final sdk = await buildSdkWithStickyBucket(svc);

        // Known good encrypted-features payload + key (reused from
        // features_view_model_extra_test.dart).
        const encryptedFeatures =
            'vMSg2Bj/IurObDsWVmvkUg==.L6qtQkIzKDoE2Dix6IAKDcVel8PHUnzJ7JjmLjFZFQDqidRIoCxKmvxvUj2kTuHFTQ3/NJ3D6XhxhXXv2+dsXpw5woQf0eAgqrcxHrbtFORs18tRXRZza7zqgzwvcznx';
        const encryptionKey = 'Ns04T5n9+59rl2x3SlNHtQ==';

        final beforeCalls = svc.getAllAssignmentsCalls;
        sdk.setEncryptedFeatures(encryptedFeatures, encryptionKey);
        await Future<void>.delayed(Duration.zero);

        expect(svc.getAllAssignmentsCalls, greaterThan(beforeCalls));
      });
    });
  });
}

class _TrackingStickyBucketService extends InMemoryStickyBucketService {
  int getAllAssignmentsCalls = 0;

  @override
  Future<Map<StickyAttributeKey, StickyAssignmentsDocument>> getAllAssignments(
      Map<String, String> attributes) {
    getAllAssignmentsCalls++;
    return super.getAllAssignments(attributes);
  }
}
