import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Utils/log_redaction.dart';

void main() {
  group('redactUrl', () {
    test('replaces the client key in a features URL', () {
      expect(
        redactUrl('https://cdn.growthbook.io/api/features/sdk-abc123'),
        'https://cdn.growthbook.io/api/features/***',
      );
    });

    test('replaces the client key in a streaming URL', () {
      expect(
        redactUrl('https://cdn.growthbook.io/sub/sdk-abc123'),
        'https://cdn.growthbook.io/sub/***',
      );
    });

    test('replaces the client key in a remote-eval URL', () {
      expect(
        redactUrl('https://cdn.growthbook.io/api/eval/sdk-abc123'),
        'https://cdn.growthbook.io/api/eval/***',
      );
    });

    test('drops the query string and fragment', () {
      expect(
        redactUrl('https://host/api/features/sdk-abc123?id=user-1#frag'),
        'https://host/api/features/***',
      );
    });

    test('handles a missing or unparsable URL', () {
      expect(redactUrl(null), '<no url>');
      expect(redactUrl(''), '<no url>');
    });

    test('never leaks the key, whatever the path shape', () {
      const key = 'sdk-secret-key';
      for (final url in [
        'https://host/api/features/$key',
        'https://host/$key',
        'http://host:8080/base/path/api/eval/$key',
      ]) {
        expect(redactUrl(url), isNot(contains(key)), reason: url);
      }
    });
  });

  group('describeRequestError', () {
    test('reports the failure without the request body', () {
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(
          path: '/api/eval/sdk-abc123',
          baseUrl: 'https://cdn.growthbook.io',
          // The remote-eval payload carries user attributes.
          data: {
            'attributes': {'id': 'user-1', 'email': 'someone@example.com'}
          },
        ),
        response: Response(
          statusCode: 401,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final described = describeRequestError(error);

      expect(described, contains('badResponse'));
      expect(described, contains('401'));
      expect(described, contains('/api/eval/***'));
      expect(described, isNot(contains('user-1')));
      expect(described, isNot(contains('someone@example.com')));
      expect(described, isNot(contains('sdk-abc123')));
    });

    test('reports an unknown error by type only', () {
      // FormatException stringifies with the offending source attached.
      expect(
        describeRequestError(const FormatException('bad', '{"id":"user-1"}')),
        'FormatException',
      );
    });
  });
}
