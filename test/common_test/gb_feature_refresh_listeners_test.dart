// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/network_mock.dart';

void main() {
  group('GrowthBookSDK — feature refresh listeners', () {
    const testApiKey = '<API_KEY>';
    const testHostURL = 'https://example.growthbook.io';
    final cachingManager = CachingManager();

    tearDown(() => cachingManager.clearCache());

    /// [ttlSeconds] defaults to 0 so the cache always counts as expired and a
    /// refresh actually reaches the network — with the default TTL a refresh
    /// right after initialization is served from cache and never fetches.
    Future<GrowthBookSDK> buildSdk({
      BaseClient? client,
      CacheRefreshHandlerV2? refreshHandlerV2,
      OnInitializationFailure? onInitializationFailure,
      int ttlSeconds = 0,
    }) {
      final builder = GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: {'id': 'user-1'},
        client: client ?? const MockNetworkClient(),
        growthBookTrackingCallBack: (_) {},
        backgroundSync: false,
        onInitializationFailure: onInitializationFailure,
        ttlSeconds: ttlSeconds,
      );
      if (refreshHandlerV2 != null) {
        builder.setRefreshHandlerV2(refreshHandlerV2);
      }
      return builder.initialize();
    }

    // -------------------------------------------------------------------------
    // Delivery
    // -------------------------------------------------------------------------
    group('delivery', () {
      test('a listener is called after a network refresh', () async {
        final sdk = await buildSdk();
        final events = <GBFeatureRefreshEvent>[];
        sdk.addFeatureRefreshListener(events.add);

        await sdk.refresh();

        expect(events, isNotEmpty);
        expect(events.last.success, isTrue);
        expect(events.last.source, GBFeatureRefreshSource.network);
        expect(events.last.error, isNull);
      });

      test('the event carries the definitions in effect', () async {
        final sdk = await buildSdk();
        final events = <GBFeatureRefreshEvent>[];
        sdk.addFeatureRefreshListener(events.add);

        await sdk.refresh();

        expect(events.last.features.keys, contains('onboarding'));
        expect(events.last.features, sdk.features);
      });

      /// The refresh handler stays silent for cached definitions, but those are
      /// what the session starts evaluating against, so listeners hear them.
      test('a listener is called for definitions read from the cache',
          () async {
        // Seed the cache the next SDK will read on startup.
        final seeded = await buildSdk();
        expect(seeded.features, isNotEmpty);

        final events = <GBFeatureRefreshEvent>[];
        final sdk = await buildSdk();
        sdk.addFeatureRefreshListener(events.add);

        await sdk.refresh();

        expect(
          events.map((e) => e.source),
          contains(GBFeatureRefreshSource.cache),
        );
      });

      test('a 304 response is reported as notModified', () async {
        // A cached payload has to exist for a 304 to mean anything.
        final cacheData = utf8.encode(MockResponse.successResponse);
        final sdk = await buildSdk(
          client: const MockNetworkClient(notModified: true),
        );
        CachingManager().putData(
          fileName: Constant.featureCache,
          content: Uint8List.fromList(cacheData),
        );

        final events = <GBFeatureRefreshEvent>[];
        sdk.addFeatureRefreshListener(events.add);
        await sdk.refresh();

        expect(
          events.map((e) => e.source),
          contains(GBFeatureRefreshSource.notModified),
        );
        expect(events.last.success, isTrue);
      });

      test('a failed refresh is reported with the error', () async {
        final sdk = await buildSdk(
          client: const MockNetworkClient(error: true),
          onInitializationFailure: (_) {},
        );
        final events = <GBFeatureRefreshEvent>[];
        sdk.addFeatureRefreshListener(events.add);

        await sdk.refresh();

        final failure = events.lastWhere((e) => !e.success);
        expect(failure.error, isNotNull);
        expect(failure.features, sdk.features,
            reason: 'evaluation keeps the definitions it had');
      });

      test('every registered listener is called', () async {
        final sdk = await buildSdk();
        var first = 0;
        var second = 0;
        sdk.addFeatureRefreshListener((_) => first++);
        sdk.addFeatureRefreshListener((_) => second++);

        await sdk.refresh();

        expect(first, greaterThan(0));
        expect(second, first);
      });
    });

    // -------------------------------------------------------------------------
    // Registration lifecycle
    // -------------------------------------------------------------------------
    group('registration', () {
      test('the returned function removes only that listener', () async {
        final sdk = await buildSdk();
        var removed = 0;
        var kept = 0;
        final stopListening = sdk.addFeatureRefreshListener((_) => removed++);
        sdk.addFeatureRefreshListener((_) => kept++);

        stopListening();
        await sdk.refresh();

        expect(removed, 0);
        expect(kept, greaterThan(0));
      });

      test('clearFeatureRefreshListeners removes all of them', () async {
        final sdk = await buildSdk();
        var calls = 0;
        sdk.addFeatureRefreshListener((_) => calls++);
        sdk.addFeatureRefreshListener((_) => calls++);

        sdk.clearFeatureRefreshListeners();
        await sdk.refresh();

        expect(calls, 0);
      });

      test('the same function can be registered twice and removed once',
          () async {
        final sdk = await buildSdk();
        var calls = 0;
        void listener(GBFeatureRefreshEvent _) => calls++;

        final stopFirst = sdk.addFeatureRefreshListener(listener);
        sdk.addFeatureRefreshListener(listener);
        stopFirst();
        await sdk.refresh();

        expect(calls, greaterThan(0),
            reason: 'the second registration is still active');
      });

      test('a stale unsubscribe handle does not remove a later registration',
          () async {
        final sdk = await buildSdk();
        var calls = 0;
        void listener(GBFeatureRefreshEvent _) => calls++;

        final stopListening = sdk.addFeatureRefreshListener(listener);
        stopListening();
        // The app re-registers the same function, then runs a stale cleanup
        // path — a dispose() called twice, for example.
        sdk.addFeatureRefreshListener(listener);
        stopListening();

        await sdk.refresh();

        expect(calls, greaterThan(0));
      });

      test('a listener can be added after initialization', () async {
        final sdk = await buildSdk();
        // Nothing was registered during initialize().
        final events = <GBFeatureRefreshEvent>[];
        sdk.addFeatureRefreshListener(events.add);

        await sdk.refresh();

        expect(events, isNotEmpty);
      });

      test(
          'a listener that unsubscribes while being called does not break '
          'the round', () async {
        final sdk = await buildSdk();
        var calls = 0;
        var otherCalls = 0;
        late VoidCallback stopListening;
        stopListening = sdk.addFeatureRefreshListener((_) {
          calls++;
          stopListening();
        });
        sdk.addFeatureRefreshListener((_) => otherCalls++);

        await sdk.refresh();
        final callsAfterFirstRound = calls;
        await sdk.refresh();

        expect(calls, callsAfterFirstRound, reason: 'it removed itself');
        expect(otherCalls, greaterThan(callsAfterFirstRound));
      });

      test('dispose removes the listeners', () async {
        final sdk = await buildSdk();
        var calls = 0;
        sdk.addFeatureRefreshListener((_) => calls++);

        await sdk.dispose();
        await sdk.refresh();

        expect(calls, 0);
      });
    });

    // -------------------------------------------------------------------------
    // Isolation
    // -------------------------------------------------------------------------
    group('isolation', () {
      test('a listener that throws does not stop the others', () async {
        final sdk = await buildSdk();
        var laterCalls = 0;
        sdk.addFeatureRefreshListener((_) => throw StateError('boom'));
        sdk.addFeatureRefreshListener((_) => laterCalls++);

        await expectLater(sdk.refresh(), completes);
        expect(laterCalls, greaterThan(0));
      });

      test('a listener that throws does not stop the refresh', () async {
        final sdk = await buildSdk();
        sdk.addFeatureRefreshListener((_) => throw StateError('boom'));

        await sdk.refresh();

        expect(sdk.features, isNotEmpty);
      });

      test('the features in an event cannot be modified', () async {
        final sdk = await buildSdk();
        final events = <GBFeatureRefreshEvent>[];
        sdk.addFeatureRefreshListener(events.add);
        await sdk.refresh();

        expect(
          () => events.last.features['injected'] = GBFeature(),
          throwsUnsupportedError,
        );
      });
    });

    // -------------------------------------------------------------------------
    // The existing refresh handler keeps working alongside listeners.
    // -------------------------------------------------------------------------
    test('the refresh handler still fires when listeners are registered',
        () async {
      final handlerCalls = <bool>[];
      final sdk = await buildSdk(
        refreshHandlerV2: (success, _) => handlerCalls.add(success),
      );
      var listenerCalls = 0;
      sdk.addFeatureRefreshListener((_) => listenerCalls++);

      await sdk.refresh();

      expect(handlerCalls, contains(true));
      expect(listenerCalls, greaterThan(0));
    });
  });
}
