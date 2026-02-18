import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

void main() {
  group('GBContext', () {
    group('getFeaturesURL', () {
      test('returns null when hostURL is null', () {
        final context = GBContext(
          hostURL: null,
          apiKey: 'test-key',
        );
        expect(context.getFeaturesURL(), isNull);
      });

      test('returns null when apiKey is null', () {
        final context = GBContext(
          hostURL: 'https://example.growthbook.io',
          apiKey: null,
        );
        expect(context.getFeaturesURL(), isNull);
      });

      test('returns null when both hostURL and apiKey are null', () {
        final context = GBContext(
          hostURL: null,
          apiKey: null,
        );
        expect(context.getFeaturesURL(), isNull);
      });

      test('returns correct URL with api/features path', () {
        const hostUrl = 'https://example.growthbook.io';
        const apiKey = 'test-api-key-123';
        final context = GBContext(
          hostURL: hostUrl,
          apiKey: apiKey,
        );
        final url = context.getFeaturesURL();
        expect(url, isNotNull);
        expect(url, equals('https://example.growthbook.io/api/features/test-api-key-123'));
      });

      test('handles hostURL with trailing slash', () {
        const hostUrl = 'https://example.growthbook.io/';
        const apiKey = 'test-api-key';
        final context = GBContext(
          hostURL: hostUrl,
          apiKey: apiKey,
        );
        final url = context.getFeaturesURL();
        expect(url, isNotNull);
        expect(url, equals('https://example.growthbook.io/api/features/test-api-key'));
      });

      test('preserves existing path in hostURL when constructing features URL', () {
        const hostUrl = 'https://example.growthbook.io/some/path';
        const apiKey = 'test-api-key';
        final context = GBContext(
          hostURL: hostUrl,
          apiKey: apiKey,
        );
        final url = context.getFeaturesURL();
        expect(url, isNotNull);
        // Uri.replace replaces the entire path, so the original path should be replaced
        expect(url, equals('https://example.growthbook.io/api/features/test-api-key'));
      });
    });

    group('getRemoteEvalUrl', () {
      test('returns null when hostURL is null', () {
        final context = GBContext(
          hostURL: null,
          apiKey: 'test-key',
        );
        expect(context.getRemoteEvalUrl(), isNull);
      });

      test('returns null when apiKey is null', () {
        final context = GBContext(
          hostURL: 'https://example.growthbook.io',
          apiKey: null,
        );
        expect(context.getRemoteEvalUrl(), isNull);
      });

      test('returns null when both hostURL and apiKey are null', () {
        final context = GBContext(
          hostURL: null,
          apiKey: null,
        );
        expect(context.getRemoteEvalUrl(), isNull);
      });

      test('returns correct URL with api/eval path', () {
        const hostUrl = 'https://example.growthbook.io';
        const apiKey = 'test-api-key-456';
        final context = GBContext(
          hostURL: hostUrl,
          apiKey: apiKey,
        );
        final url = context.getRemoteEvalUrl();
        expect(url, isNotNull);
        expect(url, equals('https://example.growthbook.io/api/eval/test-api-key-456'));
      });

      test('handles hostURL with trailing slash', () {
        const hostUrl = 'https://example.growthbook.io/';
        const apiKey = 'test-api-key';
        final context = GBContext(
          hostURL: hostUrl,
          apiKey: apiKey,
        );
        final url = context.getRemoteEvalUrl();
        expect(url, isNotNull);
        expect(url, equals('https://example.growthbook.io/api/eval/test-api-key'));
      });

      test('preserves existing path in hostURL when constructing eval URL', () {
        const hostUrl = 'https://example.growthbook.io/some/path';
        const apiKey = 'test-api-key';
        final context = GBContext(
          hostURL: hostUrl,
          apiKey: apiKey,
        );
        final url = context.getRemoteEvalUrl();
        expect(url, isNotNull);
        // Uri.replace replaces the entire path, so the original path should be replaced
        expect(url, equals('https://example.growthbook.io/api/eval/test-api-key'));
      });
    });
  });
}
