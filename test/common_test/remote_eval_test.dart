import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

import '../mocks/network_mock.dart';

class _SpyNetworkClient extends MockNetworkClient {
  int postCallCount = 0;

  @override
  Future<void> consumePostRequest(
    String baseUrl,
    Map<String, dynamic> params,
    OnSuccess onSuccess,
    OnError onError,
  ) async {
    postCallCount++;
    return super.consumePostRequest(baseUrl, params, onSuccess, onError);
  }
}

class _MockStickyBucketService implements StickyBucketService {
  @override
  Future<StickyAssignmentsDocument?> getAssignments(
          String attributeName, String attributeValue) async =>
      null;

  @override
  Future<Map<StickyAttributeKey, StickyAssignmentsDocument>> getAllAssignments(
          Map<String, String> attributes) async =>
      {};

  @override
  Future<void> saveAssignments(StickyAssignmentsDocument doc) async {}
}

void main() {
  const selfHostedUrl = 'https://my-proxy.example.com';
  const apiKey = 'test-key';

  group('remoteEval validation guards', () {
    test('throws when apiKey is empty', () async {
      expect(
        () => GBSDKBuilderApp(
          apiKey: '',
          hostURL: selfHostedUrl,
          remoteEval: true,
          client: const MockNetworkClient(),
          growthBookTrackingCallBack: (_) {},
        ).initialize(),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message',
              contains('remoteEval requires a non-empty apiKey')),
        ),
      );
    });

    test('throws when encryptionKey is set', () async {
      expect(
        () => GBSDKBuilderApp(
          apiKey: apiKey,
          hostURL: selfHostedUrl,
          encryptionKey: 'some-key',
          remoteEval: true,
          client: const MockNetworkClient(),
          growthBookTrackingCallBack: (_) {},
        ).initialize(),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message',
              contains('remoteEval is incompatible with encryptionKey')),
        ),
      );
    });

    test('throws when stickyBucketService is set', () async {
      expect(
        () => GBSDKBuilderApp(
          apiKey: apiKey,
          hostURL: selfHostedUrl,
          remoteEval: true,
          client: const MockNetworkClient(),
          growthBookTrackingCallBack: (_) {},
        ).setStickyBucketService(_MockStickyBucketService()).initialize(),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message',
              contains('remoteEval is incompatible with stickyBucketService')),
        ),
      );
    });

    test('throws when backgroundSync is true', () async {
      expect(
        () => GBSDKBuilderApp(
          apiKey: apiKey,
          hostURL: selfHostedUrl,
          remoteEval: true,
          backgroundSync: true,
          client: const MockNetworkClient(),
          growthBookTrackingCallBack: (_) {},
        ).initialize(),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message',
              contains('remoteEval is incompatible with backgroundSync')),
        ),
      );
    });

    test('throws when hostURL is a cloud host without an eval endpoint',
        () async {
      for (final host in [
        'https://cdn.growthbook.io',
        'https://api.growthbook.io'
      ]) {
        expect(
          () => GBSDKBuilderApp(
            apiKey: apiKey,
            hostURL: host,
            remoteEval: true,
            client: const MockNetworkClient(),
            growthBookTrackingCallBack: (_) {},
          ).initialize(),
          throwsA(
            isA<ArgumentError>().having((e) => e.message, 'message',
                contains('requires an evaluation endpoint')),
          ),
          reason: '$host does not serve POST /api/eval/:clientKey',
        );
      }
    });

    test('accepts a self-hosted proxy on a growthbook.io subdomain', () async {
      // Matched by exact host, not substring — a customer proxy such as
      // proxy.acme.growthbook.io is a legitimate evaluation endpoint.
      await expectLater(
        GBSDKBuilderApp(
          apiKey: apiKey,
          hostURL: 'https://proxy.acme.growthbook.io',
          remoteEval: true,
          client: const MockNetworkClient(),
          growthBookTrackingCallBack: (_) {},
        ).initialize(),
        completes,
      );
    });

    test('does not throw with valid remoteEval config', () async {
      await expectLater(
        GBSDKBuilderApp(
          apiKey: apiKey,
          hostURL: selfHostedUrl,
          remoteEval: true,
          client: const MockNetworkClient(),
          growthBookTrackingCallBack: (_) {},
        ).initialize(),
        completes,
      );
    });
  });

  group('setUrl', () {
    test('updates context url when remoteEval is false', () async {
      final sdk = await GBSDKBuilderApp(
        apiKey: apiKey,
        hostURL: selfHostedUrl,
        client: const MockNetworkClient(),
        growthBookTrackingCallBack: (_) {},
      ).initialize();

      await sdk.setUrl('https://example.com/page');
      expect(sdk.context.url, 'https://example.com/page');
    });

    test(
        'updates context url and triggers remote eval refetch when remoteEval is true',
        () async {
      final spy = _SpyNetworkClient();

      final sdk = await GBSDKBuilderApp(
        apiKey: apiKey,
        hostURL: selfHostedUrl,
        remoteEval: true,
        client: spy,
        growthBookTrackingCallBack: (_) {},
      ).initialize();

      final callsBefore = spy.postCallCount;

      await sdk.setUrl('https://example.com/new-page');

      expect(sdk.context.url, 'https://example.com/new-page');
      expect(spy.postCallCount, greaterThan(callsBefore));
    });

    test('does not trigger refetch when remoteEval is false', () async {
      final spy = _SpyNetworkClient();

      final sdk = await GBSDKBuilderApp(
        apiKey: apiKey,
        hostURL: selfHostedUrl,
        client: spy,
        growthBookTrackingCallBack: (_) {},
      ).initialize();

      final callsBefore = spy.postCallCount;

      await sdk.setUrl('https://example.com/page');

      expect(spy.postCallCount, callsBefore);
    });
  });
}
