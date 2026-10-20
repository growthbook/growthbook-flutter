import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

import '../mocks/network_mock.dart';

/// Records the remote-eval POST payloads it serves.
class _SpyNetworkClient extends MockNetworkClient {
  final List<Map<String, dynamic>> payloads = [];

  int get postCallCount => payloads.length;

  @override
  Future<void> consumePostRequest(
    String baseUrl,
    Map<String, dynamic> params,
    OnSuccess onSuccess,
    OnError onError,
  ) async {
    payloads.add(Map<String, dynamic>.from(params));
    return super.consumePostRequest(baseUrl, params, onSuccess, onError);
  }
}

void main() {
  const selfHostedUrl = 'https://my-proxy.example.com';
  const apiKey = 'test-key';

  GBSDKBuilderApp builder({
    String apiKey = apiKey,
    String hostURL = selfHostedUrl,
    String? encryptionKey,
    bool backgroundSync = false,
    String? url,
    BaseClient client = const MockNetworkClient(),
  }) {
    return GBSDKBuilderApp(
      apiKey: apiKey,
      hostURL: hostURL,
      encryptionKey: encryptionKey,
      remoteEval: true,
      backgroundSync: backgroundSync,
      url: url,
      client: client,
      growthBookTrackingCallBack: (_) {},
    );
  }

  Matcher argumentError(String message) => throwsA(
        isA<ArgumentError>()
            .having((e) => e.message, 'message', contains(message)),
      );

  // The rules mirror the GrowthBook constructor in the JS SDK.
  group('remoteEval validation', () {
    test('throws when apiKey is empty', () {
      expect(() => builder(apiKey: '').initialize(),
          argumentError('remoteEval requires an apiKey'));
    });

    test('throws when encryptionKey is set', () {
      expect(() => builder(encryptionKey: 'some-key').initialize(),
          argumentError('Encryption is not available for remoteEval'));
    });

    test('throws for every host on GrowthBook Cloud', () {
      for (final cloudHost in const [
        'https://cdn.growthbook.io',
        'https://api.growthbook.io',
        'https://proxy.acme.growthbook.io',
        'https://CDN.GrowthBook.io',
      ]) {
        expect(() => builder(hostURL: cloudHost).initialize(),
            argumentError('Cannot use remoteEval on GrowthBook Cloud'),
            reason: cloudHost);
      }
    });

    test('does not throw for a host that merely contains the cloud domain',
        () async {
      await expectLater(
          builder(hostURL: 'https://growthbook.io.example.com').initialize(),
          completes);
      await expectLater(
          builder(hostURL: 'https://proxy.example.com/growthbook.io')
              .initialize(),
          completes);
    });

    test('does not throw when a sticky bucket service is set', () async {
      await expectLater(
        builder()
            .setStickyBucketService(InMemoryStickyBucketService())
            .initialize(),
        completes,
      );
    });

    test('does not throw when backgroundSync is true', () async {
      await expectLater(builder(backgroundSync: true).initialize(), completes);
    });

    test('does not throw with a valid configuration', () async {
      await expectLater(builder().initialize(), completes);
    });

    test('does not apply without remoteEval', () async {
      await expectLater(
        GBSDKBuilderApp(
          apiKey: apiKey,
          hostURL: 'https://cdn.growthbook.io',
          encryptionKey: 'some-key',
          client: const MockNetworkClient(),
          growthBookTrackingCallBack: (_) {},
        ).initialize(),
        completes,
      );
    });
  });

  group('url in the remote-eval payload', () {
    test('is sent as an empty string when unset', () async {
      final spy = _SpyNetworkClient();
      await builder(client: spy).initialize();

      expect(spy.payloads.last['url'], '');
    });

    test('is the configured url', () async {
      final spy = _SpyNetworkClient();
      await builder(client: spy, url: 'https://example.com/start').initialize();

      expect(spy.payloads.last['url'], 'https://example.com/start');
    });
  });

  group('setUrl', () {
    test('updates the context url when remoteEval is false', () async {
      final spy = _SpyNetworkClient();
      final sdk = await GBSDKBuilderApp(
        apiKey: apiKey,
        hostURL: selfHostedUrl,
        client: spy,
        growthBookTrackingCallBack: (_) {},
      ).initialize();

      await sdk.setUrl('https://example.com/page');

      expect(sdk.context.url, 'https://example.com/page');
      expect(spy.postCallCount, 0);
    });

    test('sends the new url in a fresh remote evaluation', () async {
      final spy = _SpyNetworkClient();
      final sdk = await builder(client: spy).initialize();
      final callsBefore = spy.postCallCount;

      await sdk.setUrl('https://example.com/new-page');

      expect(sdk.context.url, 'https://example.com/new-page');
      expect(spy.postCallCount, callsBefore + 1);
      expect(spy.payloads.last['url'], 'https://example.com/new-page');
    });

    test('does nothing when the url is unchanged', () async {
      final spy = _SpyNetworkClient();
      final sdk = await builder(client: spy, url: 'https://example.com/page')
          .initialize();
      final callsBefore = spy.postCallCount;

      await sdk.setUrl('https://example.com/page');

      expect(spy.postCallCount, callsBefore);
    });
  });
}
