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
        final sdk = await buildSdk(attributes: {'id': 'user-1', 'plan': 'free'});
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
  });
}
