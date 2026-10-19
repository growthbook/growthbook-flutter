import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/network_mock.dart';

void main() {
  group('GrowthBookSDK — custom request headers and streaming host', () {
    const testApiKey = 'sdk-abc123';
    const testHostURL = 'https://cdn.example.com';
    const streamingHostURL = 'https://proxy.example.com';
    final cachingManager = CachingManager();

    tearDown(() => cachingManager.clearCache());

    Future<GrowthBookSDK> buildSdk(
      _HeaderRecordingClient client, {
      bool remoteEval = false,
      bool backgroundSync = false,
      String? streamingHost,
      Map<String, String>? apiHostRequestHeaders,
      Map<String, String>? streamingHostRequestHeaders,
    }) {
      return GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: {'id': 'user-1'},
        client: client,
        growthBookTrackingCallBack: (_) {},
        backgroundSync: backgroundSync,
        remoteEval: remoteEval,
        streamingHost: streamingHost,
        apiHostRequestHeaders: apiHostRequestHeaders,
        streamingHostRequestHeaders: streamingHostRequestHeaders,
      ).initialize();
    }

    // -------------------------------------------------------------------------
    // apiHostRequestHeaders
    // -------------------------------------------------------------------------
    group('apiHostRequestHeaders', () {
      test('are sent with the features request', () async {
        final client = _HeaderRecordingClient();
        await buildSdk(client,
            apiHostRequestHeaders: {'X-Gateway-Auth': 'token-1'});

        expect(client.gets, isNotEmpty);
        expect(client.gets.last.headers?['X-Gateway-Auth'], 'token-1');
      });

      test('are sent with the remote-evaluation request', () async {
        final client = _HeaderRecordingClient();
        await buildSdk(client,
            remoteEval: true,
            apiHostRequestHeaders: {'X-Gateway-Auth': 'token-1'});

        expect(client.posts, isNotEmpty);
        expect(client.posts.last.headers?['X-Gateway-Auth'], 'token-1');
      });

      test('are not sent to the streaming connection', () async {
        final client = _HeaderRecordingClient();
        await buildSdk(client,
            backgroundSync: true,
            apiHostRequestHeaders: {'X-Gateway-Auth': 'token-1'});

        expect(client.streams, isNotEmpty);
        expect(client.streams.last.headers?.containsKey('X-Gateway-Auth'),
            isNot(isTrue));
      });

      test('nothing is added when no headers are configured', () async {
        final client = _HeaderRecordingClient();
        await buildSdk(client);

        expect(client.gets.last.headers, anyOf(isNull, isEmpty));
      });

      /// Callers keep a reference to the map they passed in; changing it later
      /// must not change what is already being sent.
      test('a later edit of the caller map does not change the headers',
          () async {
        final client = _HeaderRecordingClient();
        final headers = {'X-Gateway-Auth': 'token-1'};
        final sdk = await buildSdk(client, apiHostRequestHeaders: headers);

        headers['X-Gateway-Auth'] = 'token-2';
        headers['X-Added-Later'] = 'nope';
        await sdk.refresh();

        expect(client.gets.last.headers?['X-Gateway-Auth'], 'token-1');
        expect(client.gets.last.headers?.containsKey('X-Added-Later'), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // streamingHost + streamingHostRequestHeaders
    // -------------------------------------------------------------------------
    group('streamingHost', () {
      test('SSE connects to it when configured', () async {
        final client = _HeaderRecordingClient();
        await buildSdk(client,
            backgroundSync: true, streamingHost: streamingHostURL);

        expect(client.streams.last.url, '$streamingHostURL/sub/$testApiKey');
      });

      test('SSE falls back to the API host when not configured', () async {
        final client = _HeaderRecordingClient();
        await buildSdk(client, backgroundSync: true);

        expect(client.streams.last.url, '$testHostURL/sub/$testApiKey');
      });

      test('features keep using the API host', () async {
        final client = _HeaderRecordingClient();
        await buildSdk(client,
            backgroundSync: true, streamingHost: streamingHostURL);

        expect(client.gets.last.url, '$testHostURL/api/features/$testApiKey');
      });

      test('remote evaluation keeps using the API host', () async {
        final client = _HeaderRecordingClient();
        await buildSdk(client,
            remoteEval: true,
            backgroundSync: true,
            streamingHost: streamingHostURL);

        expect(client.posts.last.url, '$testHostURL/api/eval/$testApiKey');
      });

      test('streamingHostRequestHeaders are applied to the SSE request',
          () async {
        final client = _HeaderRecordingClient();
        await buildSdk(client,
            backgroundSync: true,
            streamingHost: streamingHostURL,
            streamingHostRequestHeaders: {'X-Accel-Buffering': 'no'});

        expect(client.streams.last.headers?['X-Accel-Buffering'], 'no');
      });

      test('streaming headers are not sent to the API host', () async {
        final client = _HeaderRecordingClient();
        await buildSdk(client,
            backgroundSync: true,
            streamingHostRequestHeaders: {'X-Accel-Buffering': 'no'});

        expect(client.gets.last.headers?.containsKey('X-Accel-Buffering'),
            isNot(isTrue));
      });
    });

    // -------------------------------------------------------------------------
    // Validation
    // -------------------------------------------------------------------------
    group('validation', () {
      Future<void> expectArgumentError(Future<GrowthBookSDK> Function() build,
          {required String mentioning}) async {
        await expectLater(
          build(),
          throwsA(isA<ArgumentError>()
              .having((e) => e.toString(), 'message', contains(mentioning))),
        );
      }

      test('rejects a streamingHost that is not an absolute http URL',
          () async {
        for (final invalid in ['not a url', 'ftp://example.com', '/sub']) {
          await expectArgumentError(
            () => buildSdk(_HeaderRecordingClient(), streamingHost: invalid),
            mentioning: 'streamingHost',
          );
        }
      });

      test('accepts http and https streaming hosts', () async {
        await expectLater(
          buildSdk(_HeaderRecordingClient(),
              streamingHost: 'http://localhost:3300'),
          completes,
        );
      });

      test('rejects reserved header names, whatever their case', () async {
        for (final reserved in [
          'If-None-Match',
          'cache-control',
          'USER-AGENT',
        ]) {
          await expectArgumentError(
            () => buildSdk(_HeaderRecordingClient(),
                apiHostRequestHeaders: {reserved: 'x'}),
            mentioning: 'apiHostRequestHeaders',
          );
          await expectArgumentError(
            () => buildSdk(_HeaderRecordingClient(),
                streamingHostRequestHeaders: {reserved: 'x'}),
            mentioning: 'streamingHostRequestHeaders',
          );
        }
      });
    });
  });
}

class _Request {
  _Request(this.url, this.headers);

  final String url;
  final Map<String, String>? headers;
}

/// Records the URL and headers of every call the SDK makes.
class _HeaderRecordingClient implements BaseClient {
  final List<_Request> gets = [];
  final List<_Request> posts = [];
  final List<_Request> streams = [];

  @override
  Future<void> consumeGetRequest(
      String url, OnSuccess onSuccess, OnError onError,
      {Map<String, String>? headers}) async {
    gets.add(_Request(url, headers));
    await onSuccess(jsonDecode(MockResponse.successResponse));
  }

  @override
  Future<void> consumePostRequest(String baseUrl, Map<String, dynamic> params,
      OnSuccess onSuccess, OnError onError,
      {Map<String, String>? headers}) async {
    posts.add(_Request(baseUrl, headers));
    await onSuccess(jsonDecode(MockResponse.successResponse));
  }

  @override
  Future<void> consumeSseConnections(
      String url, OnSuccess onSuccess, OnError onError,
      {Map<String, String>? headers}) async {
    streams.add(_Request(url, headers));
  }
}
