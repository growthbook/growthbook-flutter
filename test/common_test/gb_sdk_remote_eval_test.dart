// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/network_mock.dart';

void main() {
  group('GrowthBookSDK — remote eval flow', () {
    const testApiKey = '<API_KEY>';
    // A self-hosted host: remote evaluation is rejected on GrowthBook Cloud,
    // and every hostname under growthbook.io counts as the cloud.
    const testHostURL = 'https://gb-proxy.example.com';
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
    // Attribute changes invalidate the remote-eval response: attributes are
    // part of the evaluation payload, so the cached response goes stale.
    // -------------------------------------------------------------------------
    group('remote-eval invalidation on attribute changes', () {
      Future<GrowthBookSDK> buildRecordingSdk(
        _RecordingNetworkClient recorder, {
        bool remoteEval = true,
        Map<String, dynamic>? attributes,
      }) {
        return GBSDKBuilderApp(
          apiKey: testApiKey,
          hostURL: testHostURL,
          attributes: attributes ?? {'id': 'user-1'},
          client: recorder,
          growthBookTrackingCallBack: (_) {},
          backgroundSync: false,
          remoteEval: remoteEval,
        ).initialize();
      }

      test(
          'updateAttributesAsync triggers a new remote request with the '
          'merged attributes', () async {
        final recorder = _RecordingNetworkClient();
        final sdk = await buildRecordingSdk(recorder,
            attributes: {'id': 'user-1', 'country': 'UA'});

        final postsAfterInit = recorder.postCount;
        await sdk.updateAttributesAsync({'plan': 'pro'});

        expect(recorder.postCount, postsAfterInit + 1);
        expect(recorder.lastPayload?['attributes'],
            {'id': 'user-1', 'country': 'UA', 'plan': 'pro'});
      });

      test(
          'setAttributesAsync triggers a new remote request with the '
          'replaced attributes', () async {
        final recorder = _RecordingNetworkClient();
        final sdk = await buildRecordingSdk(recorder,
            attributes: {'id': 'user-1', 'country': 'UA'});

        final postsAfterInit = recorder.postCount;
        await sdk.setAttributesAsync({'id': 'user-2'});

        expect(recorder.postCount, postsAfterInit + 1);
        expect(recorder.lastPayload?['attributes'], {'id': 'user-2'});
      });

      test('fire-and-forget updateAttributes also triggers a remote request',
          () async {
        final recorder = _RecordingNetworkClient();
        final sdk = await buildRecordingSdk(recorder);

        final postsAfterInit = recorder.postCount;
        sdk.updateAttributes({'plan': 'pro'});
        // The refresh is fire-and-forget and reads the feature cache before
        // posting, so give it a few event loop turns to reach the client.
        await _waitUntil(() => recorder.postCount > postsAfterInit);

        expect(recorder.postCount, greaterThan(postsAfterInit));
        expect(recorder.lastPayload?['attributes'],
            {'id': 'user-1', 'plan': 'pro'});
      });

      /// Forced features ride in the payload, so the server keeps applying the
      /// previous ones until a new round is sent.
      test('setForcedFeatures triggers a new remote request', () async {
        final recorder = _RecordingNetworkClient();
        final sdk = await buildRecordingSdk(recorder);

        final postsAfterInit = recorder.postCount;
        sdk.setForcedFeatures([
          ['feature-a', 0]
        ]);
        await _waitUntil(() => recorder.postCount > postsAfterInit);

        expect(recorder.postCount, postsAfterInit + 1);
        expect(recorder.lastPayload?['forcedFeatures'], [
          ['feature-a', 0]
        ]);
      });

      test('no remote request when remoteEval is false', () async {
        final recorder = _RecordingNetworkClient();
        final sdk = await buildRecordingSdk(recorder, remoteEval: false);

        final postsAfterInit = recorder.postCount;
        await sdk.updateAttributesAsync({'plan': 'pro'});

        expect(recorder.postCount, postsAfterInit);
      });

      /// A round in flight must not swallow the change that arrives while it
      /// runs: the response it is waiting for was evaluated for the previous
      /// attributes, so joining it would leave the SDK permanently stale.
      test('an attribute change during an in-flight round is still sent',
          () async {
        final recorder = _RecordingNetworkClient(
          postDelay: const Duration(milliseconds: 100),
        );
        final sdk = await buildRecordingSdk(recorder);

        final inFlight = sdk.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sdk.updateAttributesAsync({'plan': 'pro'});
        await inFlight;

        expect(
          recorder.payloads.map((p) => p['attributes']),
          contains(equals({'id': 'user-1', 'plan': 'pro'})),
          reason: 'the merged attributes must reach the server',
        );
      });

      test('rapid attribute changes each get their own request', () async {
        final recorder = _RecordingNetworkClient(
          postDelay: const Duration(milliseconds: 50),
        );
        final sdk = await buildRecordingSdk(recorder);

        final postsAfterInit = recorder.postCount;
        await Future.wait([
          sdk.updateAttributesAsync({'plan': 'pro'}),
          sdk.updateAttributesAsync({'country': 'UA'}),
        ]);

        expect(recorder.postCount, greaterThan(postsAfterInit + 1));
        expect(
          recorder.payloads.last['attributes'],
          {'id': 'user-1', 'plan': 'pro', 'country': 'UA'},
        );
      });
    });

    // -------------------------------------------------------------------------
    // Overlapping rounds: responses are only applied while still the latest,
    // otherwise an evaluation of the previous attributes would win.
    // -------------------------------------------------------------------------
    group('superseded remote-eval responses', () {
      Future<GrowthBookSDK> buildSdkWith(
        _OrderedNetworkClient client, {
        CacheRefreshHandler? refreshHandler,
      }) {
        return GBSDKBuilderApp(
          apiKey: testApiKey,
          hostURL: testHostURL,
          attributes: {'id': 'user-1'},
          client: client,
          growthBookTrackingCallBack: (_) {},
          backgroundSync: false,
          remoteEval: true,
          refreshHandler: refreshHandler,
          onInitializationFailure: (_) {},
        ).initialize();
      }

      test('a slow older response does not overwrite a newer one', () async {
        // Round 1 is the init fetch; round 2 is left hanging while round 3
        // answers immediately.
        final client = _OrderedNetworkClient(delays: const [
          Duration.zero,
          Duration(milliseconds: 150),
          Duration(milliseconds: 10),
        ]);
        final sdk = await buildSdkWith(client);

        // Round 2, not awaited: still in flight when the next change lands.
        final stale = sdk.refresh();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sdk.updateAttributesAsync({'plan': 'pro'}); // round 3
        await stale;

        expect(sdk.features.keys, contains('round-3'));
        expect(sdk.features.keys, isNot(contains('round-2')),
            reason: 'the stale evaluation must be discarded');
      });

      test('a superseded failure is not reported as a refresh failure',
          () async {
        final client = _OrderedNetworkClient(
          delays: const [
            Duration.zero,
            Duration(milliseconds: 150),
            Duration(milliseconds: 10),
          ],
          failingRounds: const {2},
        );
        final results = <bool>[];
        final sdk = await buildSdkWith(client, refreshHandler: results.add);

        final stale = sdk.refresh(); // round 2, fails slowly
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await sdk.updateAttributesAsync({'plan': 'pro'}); // round 3, succeeds
        results.clear();
        await stale;

        expect(results, isNot(contains(false)),
            reason: 'a round that no longer matters must stay silent');
      });
    });

    // -------------------------------------------------------------------------
    // Streamed updates: an SSE payload carries unevaluated features, so in
    // remote-eval mode it must trigger a re-evaluation, not be applied.
    // -------------------------------------------------------------------------
    group('background sync in remote-eval mode', () {
      Future<GrowthBookSDK> buildStreamingSdk(
        _StreamingNetworkClient client, {
        required bool remoteEval,
      }) {
        return GBSDKBuilderApp(
          apiKey: testApiKey,
          hostURL: testHostURL,
          attributes: {'id': 'user-1'},
          client: client,
          growthBookTrackingCallBack: (_) {},
          backgroundSync: true,
          remoteEval: remoteEval,
        ).initialize();
      }

      test(
          'a streamed payload triggers a remote evaluation instead of '
          'being applied', () async {
        final client = _StreamingNetworkClient();
        final sdk = await buildStreamingSdk(client, remoteEval: true);

        final postsBefore = client.postCount;
        await client.emitStreamedFeatures();
        await _waitUntil(() => client.postCount > postsBefore);

        expect(client.postCount, greaterThan(postsBefore),
            reason: 'the event must trigger a fresh remote evaluation');
        expect(sdk.features.keys, isNot(contains('streamed-unevaluated')),
            reason: 'unevaluated features must never reach the context');
      });

      test('a streamed payload is applied when remoteEval is off', () async {
        final client = _StreamingNetworkClient();
        final sdk = await buildStreamingSdk(client, remoteEval: false);

        await client.emitStreamedFeatures();
        await _waitUntil(
            () => sdk.features.keys.contains('streamed-unevaluated'));

        expect(sdk.features.keys, contains('streamed-unevaluated'));
        expect(client.postCount, 0);
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

/// Client that keeps the SSE callback so a test can push a streamed payload at
/// will, and counts remote-eval POSTs.
class _StreamingNetworkClient extends MockNetworkClient {
  OnSuccess? _sseCallback;
  int postCount = 0;

  @override
  Future<void> consumeSseConnections(
      String url, OnSuccess onSuccess, OnError onError) async {
    _sseCallback = onSuccess;
  }

  /// Delivers an unevaluated payload, the way the streaming endpoint does.
  Future<void> emitStreamedFeatures() async {
    await _sseCallback?.call({
      'status': 200,
      'features': {
        'streamed-unevaluated': {'defaultValue': true}
      },
    });
  }

  @override
  Future<void> consumePostRequest(String baseUrl, Map<String, dynamic> params,
      OnSuccess onSuccess, OnError onError) async {
    postCount++;
    await super.consumePostRequest(baseUrl, params, onSuccess, onError);
  }
}

/// Client whose remote-eval rounds answer after a per-round delay with a feature
/// named after the round, so tests can tell which response was applied.
class _OrderedNetworkClient extends MockNetworkClient {
  _OrderedNetworkClient({
    required this.delays,
    this.failingRounds = const {},
  });

  final List<Duration> delays;
  final Set<int> failingRounds;
  int rounds = 0;

  @override
  Future<void> consumePostRequest(String baseUrl, Map<String, dynamic> params,
      OnSuccess onSuccess, OnError onError) async {
    final round = ++rounds;
    final delay = round <= delays.length ? delays[round - 1] : delays.last;
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    if (failingRounds.contains(round)) {
      onError(StateError('round $round failed'), StackTrace.current);
      return;
    }
    await onSuccess({
      'status': 200,
      'features': {
        'round-$round': {'defaultValue': true}
      },
    });
  }
}

/// Polls [condition] until it becomes true or [timeout] elapses.
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Mock client that records the remote-eval POST requests it serves, optionally
/// holding each one open so rounds can overlap.
class _RecordingNetworkClient extends MockNetworkClient {
  _RecordingNetworkClient({this.postDelay = Duration.zero});

  final Duration postDelay;
  final List<Map<String, dynamic>> payloads = [];

  int get postCount => payloads.length;

  Map<String, dynamic>? get lastPayload =>
      payloads.isEmpty ? null : payloads.last;

  @override
  Future<void> consumePostRequest(String baseUrl, Map<String, dynamic> params,
      OnSuccess onSuccess, OnError onError) async {
    payloads.add(Map<String, dynamic>.from(params));
    if (postDelay > Duration.zero) await Future<void>.delayed(postDelay);
    await super.consumePostRequest(baseUrl, params, onSuccess, onError);
  }
}
