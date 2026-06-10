import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Network/network.dart';

class _MockSseAdapter implements HttpClientAdapter {
  final String ssePayload;
  int _callCount = 0;

  _MockSseAdapter(this.ssePayload);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_callCount++ > 0) {
      await Completer<void>().future;
    }
    final controller = StreamController<Uint8List>();
    scheduleMicrotask(() {
      controller.add(Uint8List.fromList(utf8.encode(ssePayload)));
      controller.close();
    });
    return ResponseBody(controller.stream, 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('DioClient SSE — empty data handling', () {
    test(
      'SSE features event with empty data should not throw unhandled exception',
      () async {
        const ssePayload = 'event: features\nid: 1\ndata: \n\n';
        final client = DioClient();
        client.client.httpClientAdapter = _MockSseAdapter(ssePayload);

        Object? unhandledError;
        final successCalls = <Map<String, dynamic>>[];

        await runZonedGuarded(
          () async {
            await client.listenAndRetry(
              url: 'http://test.local/sse',
              onSuccess: successCalls.add,
              onError: (_, __) {},
            );
            await pumpEventQueue();
          },
          (e, _) => unhandledError = e,
        );

        expect(unhandledError, isNull);

        expect(successCalls, isEmpty);
      },
    );

    test(
      'SSE features event with null data should not throw unhandled exception',
      () async {
        const ssePayload = 'event: features\nid: 2\n\n';
        final client = DioClient();
        client.client.httpClientAdapter = _MockSseAdapter(ssePayload);

        Object? unhandledError;
        final successCalls = <Map<String, dynamic>>[];

        await runZonedGuarded(
          () async {
            await client.listenAndRetry(
              url: 'http://test.local/sse',
              onSuccess: successCalls.add,
              onError: (_, __) {},
            );
            await pumpEventQueue();
          },
          (e, _) => unhandledError = e,
        );

        expect(unhandledError, isNull);
        expect(successCalls, isEmpty);
      },
    );

    test(
      'SSE features event with malformed JSON routes error through onError',
      () async {
        const ssePayload = 'event: features\nid: 4\ndata: {not valid json\n\n';
        final client = DioClient();
        client.client.httpClientAdapter = _MockSseAdapter(ssePayload);

        Object? unhandledError;
        final errors = <Object>[];
        final successCalls = <Map<String, dynamic>>[];

        await runZonedGuarded(
          () async {
            await client.listenAndRetry(
              url: 'http://test.local/sse',
              onSuccess: successCalls.add,
              onError: (e, _) => errors.add(e),
            );
            await pumpEventQueue();
          },
          (e, _) => unhandledError = e,
        );

        expect(unhandledError, isNull);
        expect(successCalls, isEmpty);
        expect(errors.length, 1);
        expect(errors.first, isA<FormatException>());
      },
    );

    test(
      'SSE features event with non-object JSON routes error through onError',
      () async {
        const ssePayload = 'event: features\nid: 5\ndata: [1,2,3]\n\n';
        final client = DioClient();
        client.client.httpClientAdapter = _MockSseAdapter(ssePayload);

        Object? unhandledError;
        final errors = <Object>[];
        final successCalls = <Map<String, dynamic>>[];

        await runZonedGuarded(
          () async {
            await client.listenAndRetry(
              url: 'http://test.local/sse',
              onSuccess: successCalls.add,
              onError: (e, _) => errors.add(e),
            );
            await pumpEventQueue();
          },
          (e, _) => unhandledError = e,
        );

        expect(unhandledError, isNull);
        expect(successCalls, isEmpty);
        expect(errors.length, 1);
        expect(errors.first, isA<FormatException>());
      },
    );

    test(
      'SSE features event with valid JSON data calls onSuccess correctly',
      () async {
        final payload = jsonEncode({'status': 200, 'features': {}});
        final ssePayload = 'event: features\nid: 3\ndata: $payload\n\n';
        final client = DioClient();
        client.client.httpClientAdapter = _MockSseAdapter(ssePayload);

        Object? unhandledError;
        final successCalls = <Map<String, dynamic>>[];

        await runZonedGuarded(
          () async {
            await client.listenAndRetry(
              url: 'http://test.local/sse',
              onSuccess: successCalls.add,
              onError: (_, __) {},
            );
            await pumpEventQueue();
          },
          (e, _) => unhandledError = e,
        );

        expect(unhandledError, isNull);
        expect(successCalls.length, 1);
        expect(successCalls.first['status'], 200);
      },
    );
  });
}
