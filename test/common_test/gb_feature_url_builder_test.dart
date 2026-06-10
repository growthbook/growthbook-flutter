import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Utils/feature_url_builder.dart';

void main() {
  group('FeatureURLBuilder', () {
    group('buildUrl - features (STALE_WHILE_REVALIDATE)', () {
      test('returns correct URL with api/features path', () {
        final url = FeatureURLBuilder(apiHost: 'https://example.growthbook.io')
            .buildUrl('test-api-key-123');
        expect(url, equals('https://example.growthbook.io/api/features/test-api-key-123'));
      });

      test('handles apiHost with trailing slash', () {
        final url = FeatureURLBuilder(apiHost: 'https://example.growthbook.io/')
            .buildUrl('test-api-key');
        expect(url, equals('https://example.growthbook.io/api/features/test-api-key'));
      });

      test('handles apiHost with existing path segment', () {
        final url = FeatureURLBuilder(apiHost: 'https://example.growthbook.io/some/path')
            .buildUrl('test-api-key');
        expect(url, equals('https://example.growthbook.io/api/features/test-api-key'));
      });

      test('falls back to defaultHost when apiHost is null', () {
        final url = FeatureURLBuilder(apiHost: null).buildUrl('test-api-key');
        expect(url, equals('https://cdn.growthbook.io/api/features/test-api-key'));
      });
    });

    group('buildUrl - remote eval (SERVER_SENT_REMOTE_FEATURE_EVAL)', () {
      test('returns correct URL with api/eval path', () {
        final url = FeatureURLBuilder(apiHost: 'https://example.growthbook.io')
            .buildUrl('test-api-key-456',
                featureRefreshStrategy:
                    FeatureRefreshStrategy.SERVER_SENT_REMOTE_FEATURE_EVAL);
        expect(url, equals('https://example.growthbook.io/api/eval/test-api-key-456'));
      });

      test('handles apiHost with trailing slash', () {
        final url = FeatureURLBuilder(apiHost: 'https://example.growthbook.io/')
            .buildUrl('test-api-key',
                featureRefreshStrategy:
                    FeatureRefreshStrategy.SERVER_SENT_REMOTE_FEATURE_EVAL);
        expect(url, equals('https://example.growthbook.io/api/eval/test-api-key'));
      });

      test('falls back to defaultHost when apiHost is null', () {
        final url = FeatureURLBuilder(apiHost: null).buildUrl('test-api-key',
            featureRefreshStrategy:
                FeatureRefreshStrategy.SERVER_SENT_REMOTE_FEATURE_EVAL);
        expect(url, equals('https://cdn.growthbook.io/api/eval/test-api-key'));
      });
    });

    group('buildUrl - streaming (SERVER_SENT_EVENTS)', () {
      test('uses streamingHost instead of apiHost', () {
        final url = FeatureURLBuilder(
          apiHost: 'https://api.growthbook.io',
          streamingHost: 'https://streaming.growthbook.io',
        ).buildUrl('test-api-key',
            featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS);
        expect(url, equals('https://streaming.growthbook.io/sub/test-api-key'));
      });

      test('falls back to defaultHost when streamingHost is null', () {
        final url = FeatureURLBuilder(
          apiHost: 'https://api.growthbook.io',
          streamingHost: null,
        ).buildUrl('test-api-key',
            featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS);
        expect(url, equals('https://cdn.growthbook.io/sub/test-api-key'));
      });
    });
  });
}
