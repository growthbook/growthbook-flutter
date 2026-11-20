import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/Utils/poll_backoff.dart';

import '../mocks/network_mock.dart';

void main() {
  group('pollBackoffDelay', () {
    // A fixed sequence keeps the jitter out of the assertions.
    Random noJitter() => _FixedRandom(0);

    test('returns the interval unchanged while healthy', () {
      expect(
        pollBackoffDelay(const Duration(seconds: 30), 0, random: noJitter()),
        const Duration(seconds: 30),
      );
    });

    test('doubles per consecutive failure', () {
      const interval = Duration(seconds: 30);
      expect(pollBackoffDelay(interval, 1, random: noJitter()),
          const Duration(seconds: 30));
      expect(pollBackoffDelay(interval, 2, random: noJitter()),
          const Duration(minutes: 1));
      expect(pollBackoffDelay(interval, 3, random: noJitter()),
          const Duration(minutes: 2));
    });

    test('is capped at five minutes however long the outage lasts', () {
      for (final failures in [5, 10, 100, 1000000]) {
        expect(
          pollBackoffDelay(const Duration(seconds: 30), failures,
              random: noJitter()),
          maxPollBackoff,
          reason: 'after $failures failures',
        );
      }
    });

    test('spreads the delay by up to the delay itself', () {
      const interval = Duration(seconds: 30);
      final full = pollBackoffDelay(interval, 1, random: _FixedRandom(1));
      final half = pollBackoffDelay(interval, 1, random: _FixedRandom(0.5));

      expect(full, const Duration(seconds: 60));
      expect(half, const Duration(seconds: 45));
    });

    test('a cap plus jitter never exceeds twice the cap', () {
      final delay = pollBackoffDelay(const Duration(seconds: 30), 9,
          random: _FixedRandom(1));
      expect(delay, maxPollBackoff * 2);
    });

    /// The cap was written for intervals below it. Applied to a longer one it
    /// would poll a host that is down more often than a healthy one.
    test('a failing host is never polled sooner than a healthy one', () {
      const interval = Duration(minutes: 15);
      for (final failures in [1, 2, 5, 100]) {
        expect(
          pollBackoffDelay(interval, failures, random: noJitter()),
          greaterThanOrEqualTo(interval),
          reason: 'after $failures failures',
        );
      }
    });

    /// Duration holds microseconds in a 64-bit int: interval * 2^exponent
    /// wraps negative for any interval above a couple of hours, and a negative
    /// delay fires immediately — requests back to back for the whole outage.
    test('a long interval does not overflow into an immediate retry', () {
      const interval = Duration(hours: 3);
      for (final failures in [20, 31, 1000000]) {
        expect(
          pollBackoffDelay(interval, failures, random: noJitter()),
          greaterThanOrEqualTo(interval),
          reason: 'after $failures failures',
        );
      }
    });
  });

  group('GrowthBookSDK — polling', () {
    const testApiKey = '<API_KEY>';
    const testHostURL = 'https://example.growthbook.io';
    final cachingManager = CachingManager();

    tearDown(() => cachingManager.clearCache());

    Future<GrowthBookSDK> buildSdk({
      BaseClient? client,
      Duration? pollingInterval,
      bool backgroundSync = false,
      bool remoteEval = false,
      int ttlSeconds = 60,
      OnInitializationFailure? onInitializationFailure,
    }) {
      return GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: {'id': 'user-1'},
        client: client ?? const MockNetworkClient(),
        growthBookTrackingCallBack: (_) {},
        backgroundSync: backgroundSync,
        remoteEval: remoteEval,
        ttlSeconds: ttlSeconds,
        pollingInterval: pollingInterval,
        onInitializationFailure: onInitializationFailure,
      ).initialize();
    }

    /// Waits until [condition] holds or the budget runs out, so the assertions
    /// do not depend on exact timer scheduling.
    Future<void> waitUntil(bool Function() condition,
        {Duration timeout = const Duration(seconds: 2)}) async {
      final deadline = DateTime.now().add(timeout);
      while (!condition() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    // -------------------------------------------------------------------------
    // Starting and stopping
    // -------------------------------------------------------------------------
    group('lifecycle', () {
      test('nothing polls until startPolling is called', () async {
        final client = _CountingClient();
        final sdk = await buildSdk(
          client: client,
          pollingInterval: const Duration(milliseconds: 20),
        );

        final afterInit = client.gets;
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(sdk.isPolling, isFalse);
        expect(client.gets, afterInit);
      });

      test('startPolling refreshes on the interval', () async {
        final client = _CountingClient();
        final sdk = await buildSdk(
          client: client,
          pollingInterval: const Duration(milliseconds: 20),
        );

        final afterInit = client.gets;
        expect(sdk.startPolling(), isTrue);
        await waitUntil(() => client.gets >= afterInit + 2);

        expect(client.gets, greaterThanOrEqualTo(afterInit + 2));
        sdk.stopPolling();
      });

      test('stopPolling stops the requests', () async {
        final client = _CountingClient();
        final sdk = await buildSdk(
          client: client,
          pollingInterval: const Duration(milliseconds: 20),
        );
        sdk.startPolling();
        await waitUntil(() => client.gets > 1);

        sdk.stopPolling();
        final afterStop = client.gets;
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(sdk.isPolling, isFalse);
        expect(client.gets, afterStop);
      });

      test('startPolling is a no-op while already polling', () async {
        final client = _CountingClient();
        final sdk = await buildSdk(
          client: client,
          pollingInterval: const Duration(milliseconds: 50),
        );

        expect(sdk.startPolling(), isTrue);
        expect(sdk.startPolling(), isTrue, reason: 'already running');
        await waitUntil(() => client.gets > 1);
        sdk.stopPolling();

        // One loop, not two: a second loop would roughly double the count.
        expect(client.gets, lessThan(6));
      });

      /// A Timer that has already fired cannot be cancelled, so a round that
      /// outlives its own loop has to notice: the quick inactive -> resumed the
      /// README warns about would otherwise leave two loops polling forever.
      test('restarting during an in-flight round leaves a single loop',
          () async {
        final client = _CountingClient();
        final sdk = await buildSdk(
          client: client,
          pollingInterval: const Duration(milliseconds: 20),
        );

        final gate = Completer<void>();
        client.gate = gate;
        sdk.startPolling();
        final heldAt = client.gets;
        await waitUntil(() => client.gets > heldAt);

        sdk.stopPolling();
        expect(sdk.startPolling(), isTrue);

        client.gate = null;
        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // One stopPolling() has to be enough: a stale round that rescheduled
        // would have replaced the live timer with its own, leaving the live one
        // running where nothing can reach it.
        sdk.stopPolling();
        final afterStop = client.gets;
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(client.gets, afterStop);
      });

      test('stopPolling is safe when nothing is running', () async {
        final sdk = await buildSdk(pollingInterval: const Duration(seconds: 1));
        expect(sdk.stopPolling, returnsNormally);
      });

      test('dispose stops polling', () async {
        final client = _CountingClient();
        final sdk = await buildSdk(
          client: client,
          pollingInterval: const Duration(milliseconds: 20),
        );
        sdk.startPolling();
        await waitUntil(() => client.gets > 1);

        await sdk.dispose();
        final afterDispose = client.gets;
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(sdk.isPolling, isFalse);
        expect(client.gets, afterDispose);
      });
    });

    // -------------------------------------------------------------------------
    // Refusals
    // -------------------------------------------------------------------------
    group('refusals', () {
      test('refuses without a configured interval', () async {
        final sdk = await buildSdk();

        expect(sdk.startPolling(), isFalse);
        expect(sdk.isPolling, isFalse);
      });

      /// Both reach the same endpoint and the stream is cheaper, so enabling
      /// both must not double the traffic.
      test('refuses while streaming is on', () async {
        final client = _CountingClient();
        final sdk = await buildSdk(
          client: client,
          backgroundSync: true,
          pollingInterval: const Duration(milliseconds: 20),
        );

        expect(sdk.startPolling(), isFalse);
        expect(sdk.isPolling, isFalse);
      });

      test('a non-positive interval is rejected at initialization', () async {
        for (final invalid in [Duration.zero, const Duration(seconds: -1)]) {
          await expectLater(
            buildSdk(pollingInterval: invalid),
            throwsA(isA<ArgumentError>().having(
                (e) => e.toString(), 'message', contains('pollingInterval'))),
          );
        }
      });
    });

    // -------------------------------------------------------------------------
    // Each round has to reach the network
    // -------------------------------------------------------------------------
    test('a round ignores the cache TTL', () async {
      final client = _CountingClient();
      // An interval far shorter than the TTL: without the bypass the cache
      // would still be fresh every round and no request would go out.
      final sdk = await buildSdk(
        client: client,
        pollingInterval: const Duration(milliseconds: 20),
        ttlSeconds: 3600,
      );

      final afterInit = client.gets;
      sdk.startPolling();
      await waitUntil(() => client.gets >= afterInit + 2);
      sdk.stopPolling();

      expect(client.gets, greaterThanOrEqualTo(afterInit + 2));
    });

    test('a failing host does not stop the loop', () async {
      final client = _CountingClient(fail: true);
      final sdk = await buildSdk(
        client: client,
        pollingInterval: const Duration(milliseconds: 20),
        onInitializationFailure: (_) {},
      );

      final afterInit = client.gets;
      sdk.startPolling();
      // Backoff widens the gaps, so two more rounds is the useful assertion.
      await waitUntil(() => client.gets >= afterInit + 2,
          timeout: const Duration(seconds: 3));
      sdk.stopPolling();

      expect(client.gets, greaterThanOrEqualTo(afterInit + 2));
      expect(sdk.isPolling, isFalse);
    });

    /// An outage reporting an "initialization failure" every round, long after
    /// initialization succeeded, would have apps showing an error screen or
    /// re-initializing on a loop.
    test('a failed poll is not an initialization failure', () async {
      final client = _CountingClient(failAfterGets: 1);
      var initFailures = 0;
      final sdk = await buildSdk(
        client: client,
        pollingInterval: const Duration(milliseconds: 20),
        onInitializationFailure: (_) => initFailures++,
      );

      final afterInit = client.gets;
      expect(initFailures, 0, reason: 'the first load succeeded');

      sdk.startPolling();
      await waitUntil(() => client.gets >= afterInit + 2,
          timeout: const Duration(seconds: 3));
      sdk.stopPolling();

      expect(client.gets, greaterThanOrEqualTo(afterInit + 2),
          reason: 'the rounds that follow failed');
      expect(initFailures, 0);
    });

    test('a failure before the first load still reports initialization',
        () async {
      var initFailures = 0;
      await buildSdk(
        client: _CountingClient(fail: true),
        pollingInterval: const Duration(milliseconds: 20),
        onInitializationFailure: (_) => initFailures++,
      );

      expect(initFailures, greaterThan(0));
    });

    test('polling refreshes remotely evaluated features', () async {
      final client = _CountingClient();
      final sdk = await buildSdk(
        client: client,
        remoteEval: true,
        pollingInterval: const Duration(milliseconds: 20),
      );

      final afterInit = client.posts;
      sdk.startPolling();
      await waitUntil(() => client.posts >= afterInit + 2);
      sdk.stopPolling();

      expect(client.posts, greaterThanOrEqualTo(afterInit + 2));
    });
  });
}

/// Random stub returning a fixed value, so jitter is out of the assertions.
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}

/// Counts the requests the SDK makes, and can fail them all, fail them from a
/// given request on, or hold one in flight.
class _CountingClient implements BaseClient {
  _CountingClient({this.fail = false, this.failAfterGets});

  final bool fail;

  /// Requests past this many GETs fail: a host that goes down after the SDK
  /// has already loaded its features.
  final int? failAfterGets;

  /// While set, requests park here instead of answering — a round in flight.
  Completer<void>? gate;

  int gets = 0;
  int posts = 0;

  bool _shouldFail(int count) =>
      fail || (failAfterGets != null && count > failAfterGets!);

  @override
  Future<void> consumeGetRequest(
      String url, OnSuccess onSuccess, OnError onError) async {
    gets++;
    final shouldFail = _shouldFail(gets);
    await gate?.future;
    if (shouldFail) {
      onError(StateError('host down'), StackTrace.current);
      return;
    }
    await onSuccess(jsonDecode(MockResponse.successResponse));
  }

  @override
  Future<void> consumePostRequest(String baseUrl, Map<String, dynamic> params,
      OnSuccess onSuccess, OnError onError) async {
    posts++;
    await gate?.future;
    if (fail) {
      onError(StateError('host down'), StackTrace.current);
      return;
    }
    await onSuccess(jsonDecode(MockResponse.successResponse));
  }

  @override
  Future<void> consumeSseConnections(
      String url, OnSuccess onSuccess, OnError onError) async {}
}
