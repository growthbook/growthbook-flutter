import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Network/network.dart';

// ---------------------------------------------------------------------------
// Minimal mock HttpClientAdapter
// ---------------------------------------------------------------------------
typedef _AdapterHandler = Future<ResponseBody> Function(RequestOptions options);

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._handler);
  final _AdapterHandler _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestBodyBytes,
    Future<void>? cancelFuture,
  ) =>
      _handler(options);

  @override
  void close({bool force = false}) {}
}

// Stateful mock that succeeds once then throws to break SSE reconnect loop.
class _OnceThenErrorAdapter implements HttpClientAdapter {
  int _calls = 0;
  final ResponseBody firstResponse;

  _OnceThenErrorAdapter(this.firstResponse);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestBodyBytes,
    Future<void>? cancelFuture,
  ) async {
    _calls++;
    if (_calls == 1) return firstResponse;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'reconnect cancelled by test',
    );
  }

  @override
  void close({bool force = false}) {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
DioClient _clientWith(_AdapterHandler handler) {
  final c = DioClient();
  c.client.httpClientAdapter = _MockAdapter(handler);
  return c;
}

void main() {
  group('DioClient', () {
    // -----------------------------------------------------------------------
    // Pure-logic / trivial
    // -----------------------------------------------------------------------
    group('shouldReconnect', () {
      test('returns true for 2xx status codes', () {
        final c = DioClient();
        expect(c.shouldReconnect(200), isTrue);
        expect(c.shouldReconnect(201), isTrue);
        expect(c.shouldReconnect(299), isTrue);
      });

      test('returns false for status codes outside 2xx', () {
        final c = DioClient();
        expect(c.shouldReconnect(300), isFalse);
        expect(c.shouldReconnect(400), isFalse);
        expect(c.shouldReconnect(500), isFalse);
        expect(c.shouldReconnect(199), isFalse);
      });
    });

    test('client getter returns the Dio instance', () {
      final c = DioClient();
      expect(c.client, isA<Dio>());
    });

    // -----------------------------------------------------------------------
    // consumeGetRequest
    // -----------------------------------------------------------------------
    group('consumeGetRequest', () {
      test('calls onSuccess with decoded map on 200 JSON response', () async {
        final c = _clientWith((_) async => ResponseBody.fromString(
                '{"status":200,"features":{}}', 200,
                headers: {
                  'content-type': ['application/json']
                }));

        Map<String, dynamic>? received;
        await c.consumeGetRequest(
          'http://test.com/data',
          (data) async {
            received = data;
          },
          (e, s) => fail('onError should not be called: $e'),
        );

        expect(received, isNotNull);
        expect(received!['status'], 200);
      });

      test('calls onSuccess when response.data is a plain JSON string',
          () async {
        final c = DioClient();
        c.client.options.responseType = ResponseType.plain;
        c.client.httpClientAdapter = _MockAdapter(
            (_) async => ResponseBody.fromString('{"key":"value"}', 200));

        Map<String, dynamic>? received;
        await c.consumeGetRequest(
          'http://test.com/data',
          (data) async {
            received = data;
          },
          (e, s) => fail('onError should not be called: $e'),
        );

        expect(received, isNotNull);
        expect(received!['key'], 'value');
      });

      test('calls onError when string response is not valid JSON', () async {
        final c = DioClient();
        c.client.options.responseType = ResponseType.plain;
        c.client.httpClientAdapter =
            _MockAdapter((_) async => ResponseBody.fromString('not json', 200));

        Object? capturedError;
        await c.consumeGetRequest(
          'http://test.com/data',
          (data) => fail('onSuccess should not be called'),
          (e, s) => capturedError = e,
        );

        expect(capturedError, isNotNull);
      });

      test('calls onError when response format is unexpected', () async {
        // A JSON array is neither Map nor String → unexpected format
        final c = _clientWith(
            (_) async => ResponseBody.fromString('[1,2,3]', 200, headers: {
                  'content-type': ['application/json']
                }));

        Object? capturedError;
        await c.consumeGetRequest(
          'http://test.com/data',
          (data) => fail('onSuccess should not be called'),
          (e, s) => capturedError = e,
        );

        expect(capturedError, isNotNull);
      });

      test('returns without calling callbacks on 304 Not Modified', () async {
        final c = DioClient();
        c.client.httpClientAdapter =
            _MockAdapter((_) async => ResponseBody.fromString('', 304));
        c.client.options.validateStatus =
            (s) => s != null && (s >= 200 && s < 300 || s == 304);

        bool successCalled = false;
        bool errorCalled = false;

        await c.consumeGetRequest(
          'http://test.com/data',
          (_) async {
            successCalled = true;
          },
          (e, s) => errorCalled = true,
        );

        expect(successCalled, isFalse);
        expect(errorCalled, isFalse);
      });

      test('stores etag from features URL response', () async {
        const featuresUrl = 'http://test.com/api/features/mykey';

        final c = _clientWith((_) async => ResponseBody.fromString(
              '{"features":{}}',
              200,
              headers: {
                'content-type': ['application/json'],
                'etag': ['"abc123"'],
              },
            ));

        RequestOptions? secondRequestOptions;
        int callCount = 0;
        c.client.httpClientAdapter = _MockAdapter((options) async {
          callCount++;
          if (callCount == 1) {
            return ResponseBody.fromString('{"features":{}}', 200, headers: {
              'content-type': ['application/json'],
              'etag': ['"abc123"'],
            });
          }
          secondRequestOptions = options;
          return ResponseBody.fromString('{"features":{}}', 200, headers: {
            'content-type': ['application/json']
          });
        });

        await c.consumeGetRequest(featuresUrl, (_) async {}, (e, s) {});
        await c.consumeGetRequest(featuresUrl, (_) async {}, (e, s) {});

        expect(secondRequestOptions?.headers['If-None-Match'], '"abc123"');
      });

      test('does not add etag headers for non-features URLs', () async {
        const nonFeaturesUrl = 'http://test.com/other/path';

        RequestOptions? capturedOptions;
        final c = _clientWith((options) async {
          capturedOptions = options;
          return ResponseBody.fromString('{"data":1}', 200, headers: {
            'content-type': ['application/json']
          });
        });

        await c.consumeGetRequest(nonFeaturesUrl, (_) async {}, (e, s) {});

        expect(capturedOptions?.headers.containsKey('If-None-Match'), isFalse);
        expect(capturedOptions?.headers.containsKey('Cache-Control'), isFalse);
      });

      test('calls onError on DioException', () async {
        final c = DioClient();
        c.client.httpClientAdapter = _MockAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        });

        Object? capturedError;
        await c.consumeGetRequest(
          'http://test.com/data',
          (_) => fail('onSuccess should not be called'),
          (e, s) => capturedError = e,
        );

        expect(capturedError, isA<DioException>());
      });

      test('calls onError on unexpected exception', () async {
        final c = DioClient();
        c.client.httpClientAdapter =
            _MockAdapter((_) async => throw Exception('boom'));

        Object? capturedError;
        await c.consumeGetRequest(
          'http://test.com/data',
          (_) => fail('onSuccess should not be called'),
          (e, s) => capturedError = e,
        );

        expect(capturedError, isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    // consumePostRequest
    // -----------------------------------------------------------------------
    group('consumePostRequest', () {
      test('calls onSuccess with decoded response on success', () async {
        final c = _clientWith((_) async => ResponseBody.fromString(
              '{"result":"ok"}',
              200,
              headers: {
                'content-type': ['application/json']
              },
            ));

        Map<String, dynamic>? received;
        await c.consumePostRequest(
          'http://test.com/api',
          {'key': 'value'},
          (data) async {
            received = data;
          },
          (e, s) => fail('onError should not be called: $e'),
        );

        expect(received, isNotNull);
        expect(received!['result'], 'ok');
      });

      test('calls onError when POST request throws', () async {
        final c = DioClient();
        c.client.httpClientAdapter = _MockAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        });

        Object? capturedError;
        await c.consumePostRequest(
          'http://test.com/api',
          {},
          (_) => fail('onSuccess should not be called'),
          (e, s) => capturedError = e,
        );

        expect(capturedError, isA<DioException>());
      });
    });

    // -----------------------------------------------------------------------
    // consumeSseConnections / listenAndRetry
    // -----------------------------------------------------------------------
    group('consumeSseConnections', () {
      test('delivers SSE event to onSuccess callback', () async {
        const ssePayload =
            'id: 1\nevent: features\ndata: {"status":200,"features":{}}\n\n';

        final c = DioClient();
        c.client.httpClientAdapter = _OnceThenErrorAdapter(
          ResponseBody.fromString(ssePayload, 200, headers: {
            'content-type': ['text/event-stream']
          }),
        );

        final completer = Completer<Map<String, dynamic>>();
        await c.consumeSseConnections(
          'http://test.com/sse',
          (data) async {
            if (!completer.isCompleted) completer.complete(data);
          },
          (e, s) {
            // reconnect failure is expected; ignore after onSuccess
          },
        );

        final result = await completer.future;
        expect(result, isNotNull);
      });

      test('calls onError when SSE connection fails immediately', () async {
        final c = DioClient();
        c.client.httpClientAdapter = _MockAdapter((options) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        });

        Object? capturedError;
        await c.consumeSseConnections(
          'http://test.com/sse',
          (_) async {},
          (e, s) => capturedError = e,
        );

        expect(capturedError, isNotNull);
      });
    });
  });
}
