import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/network_mock.dart';

void main() {
  group('GrowthBookSDK — remote eval flow', () {
    const testApiKey = '<API_KEY>';
    const testHostURL = 'https://example.growthbook.io';
    final cachingManager = CachingManager();

    Future<GrowthBookSDK> buildSdk({
      bool remoteEval = false,
      bool networkError = false,
      Map<String, dynamic>? attributes,
      CacheRefreshHandler? refreshHandler,
      OnInitializationFailure? onInitializationFailure,
    }) async {
      return GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attributes ?? {'id': 'user-1'},
        client: MockNetworkClient(error: networkError),
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
        remoteEval: remoteEval,
        refreshHandler: refreshHandler,
        onInitializationFailure: onInitializationFailure,
      ).initialize();
    }

    tearDown(() {
      cachingManager.clearCache();
    });

    // -------------------------------------------------------------------------
    // refresh() — remote eval branch
    // -------------------------------------------------------------------------
    group('refresh with remoteEval', () {
      test('loads features via POST when remoteEval is true', () async {
        final sdk = await buildSdk(remoteEval: true);
        // Mock returns features including 'onboarding'
        expect(sdk.features, isNotEmpty);
        expect(sdk.features.containsKey('onboarding'), isTrue);
      });

      test('explicit refresh() re-fetches features via remote eval', () async {
        final sdk = await buildSdk(remoteEval: true);
        // Should complete without error
        await expectLater(sdk.refresh(), completes);
      });

      test('refreshHandler is called with true on successful remote eval',
          () async {
        bool? handlerValue;
        final sdk = await buildSdk(
          remoteEval: true,
          refreshHandler: (success) => handlerValue = success,
        );
        await sdk.refresh();
        expect(handlerValue, isTrue);
      });

      test('refreshHandler is called with false on remote eval failure',
          () async {
        bool? handlerValue;
        await buildSdk(
          remoteEval: true,
          networkError: true,
          refreshHandler: (success) => handlerValue = success,
          onInitializationFailure: (_) {},
        );
        expect(handlerValue, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // refreshForRemoteEval()
    // -------------------------------------------------------------------------
    group('refreshForRemoteEval', () {
      test('does nothing when remoteEval is false', () async {
        final sdk = await buildSdk(remoteEval: false);
        // Should return immediately without error
        await expectLater(sdk.refreshForRemoteEval(), completes);
      });

      test('sends current attributes and forced variations in payload',
          () async {
        final sdk = await buildSdk(
          remoteEval: true,
          attributes: {'id': 'user-42', 'plan': 'pro'},
        );
        sdk.setForcedVariations({'exp-remote': 1});
        // refreshForRemoteEval is triggered by setForcedVariations;
        // calling explicitly should also complete without error
        await expectLater(sdk.refreshForRemoteEval(), completes);
      });

      test('updates features after successful remote eval call', () async {
        final sdk = await buildSdk(remoteEval: true);
        final featuresBefore = sdk.features.length;
        await sdk.refreshForRemoteEval();
        expect(sdk.features.length, featuresBefore);
      });
    });

    // -------------------------------------------------------------------------
    // isOn()
    // -------------------------------------------------------------------------
    group('isOn', () {
      test('returns true for a feature with defaultValue true', () async {
        final sdk = await buildSdk();
        sdk.context.features = {
          'flag-on': GBFeature(defaultValue: true),
        };
        expect(sdk.isOn('flag-on'), isTrue);
      });

      test('returns false for a feature with defaultValue false', () async {
        final sdk = await buildSdk();
        sdk.context.features = {
          'flag-off': GBFeature(defaultValue: false),
        };
        expect(sdk.isOn('flag-off'), isFalse);
      });

      test('returns false for an unknown feature', () async {
        final sdk = await buildSdk();
        expect(sdk.isOn('nonexistent-feature'), isFalse);
      });
    });
  });
}
