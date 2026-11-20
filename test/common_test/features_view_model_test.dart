import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';

import '../mocks/network_mock.dart';
import '../mocks/network_view_model_mock.dart';

void main() {
  group(
    'Feature viewModel group test',
    () {
      late FeatureViewModel featureViewModel;
      late DataSourceMock dataSourceMock;
      late GBContext context;
      const testApiKey = '<SOME KEY>';
      const attr = <String, String>{};
      const testHostURL = '<HOST URL>';

      setUp(
        () {
          context = GBContext(
            apiKey: testApiKey,
            hostURL: testHostURL,
            attributes: attr,
            enabled: true,
            forcedVariation: {},
            qaMode: false,
            trackingCallBack: (_) {},
          );
          dataSourceMock = DataSourceMock();
        },
      );

      tearDown(() async {
        await CachingManager().clearCache();
      });
      test(
        'Success feature-view model.',
        () async {
          featureViewModel = FeatureViewModel(
            encryptionKey: testApiKey,
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(),
              context: context,
            ),
          );
          await featureViewModel.fetchFeatures(context.getFeaturesURL());
          expect(dataSourceMock.isSuccess, true);
        },
      );

      test('Success for encrypted features test', () async {
        featureViewModel = FeatureViewModel(
          encryptionKey: "3tfeoyW0wlo47bDnbWDkxg==",
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const MockNetworkClient(),
            context: context,
          ),
        );

        await featureViewModel.fetchFeatures(context.getFeaturesURL());
        expect(dataSourceMock.isSuccess, true);
      });

      test('Remote eval success test', () async {
        featureViewModel = FeatureViewModel(
          encryptionKey: testApiKey,
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const MockNetworkClient(),
            context: context,
          ),
        );

        final forcedFeature = {'feature': 123};
        final forcedVariation = {'feature': 123};
        final attributes = <String, dynamic>{};
        final payload = RemoteEvalModel(
          attributes: attributes,
          forcedFeatures: forcedFeature.entries
              .map((entry) => [entry.key, entry.value])
              .toList(),
          forcedVariations: forcedVariation,
        );

        await featureViewModel.fetchFeatures('',
            remoteEval: true, payload: payload);
        expect(dataSourceMock.isSuccess, true);
      });

      test('Remote eval failed test', () async {
        featureViewModel = FeatureViewModel(
          encryptionKey: '',
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const MockNetworkClient(
              error: true,
            ),
            context: context,
          ),
        );

        final forcedFeature = {'feature': 123};
        final forcedVariation = {'feature': 123};
        final attributes = <String, dynamic>{};
        final payload = RemoteEvalModel(
          attributes: attributes,
          forcedFeatures: forcedFeature.entries
              .map((entry) => [entry.key, entry.value])
              .toList(),
          forcedVariations: forcedVariation,
        );

        await featureViewModel.fetchFeatures('',
            remoteEval: true, payload: payload);

        expect(dataSourceMock.isError, true);
      });
      test('Error test', () async {
        final viewModel = FeatureViewModel(
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const MockNetworkClient(
              error: true,
            ),
            context: context,
          ),
          encryptionKey: '',
        );

        await viewModel.fetchFeatures('');
        expect(dataSourceMock.isError, true);
      });

      test(
        '304 Not Modified should not report error and should refresh TTL',
        () async {
          await CachingManager().clearCache();

          featureViewModel = FeatureViewModel(
            encryptionKey: testApiKey,
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(notModified: true),
              context: context,
            ),
            ttlSeconds: 60,
          );

          await featureViewModel.fetchFeatures(context.getFeaturesURL());

          // 304 means "cache is still valid" -- not an error
          expect(dataSourceMock.isError, false);
          expect(dataSourceMock.isSuccess, false);
        },
      );

      test(
        '304 Not Modified without cache should NOT call featuresNotModified()',
        () async {
          await CachingManager().clearCache();

          featureViewModel = FeatureViewModel(
            encryptionKey: testApiKey,
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(notModified: true),
              context: context,
            ),
            ttlSeconds: 60,
          );

          await featureViewModel.fetchFeatures(context.getFeaturesURL());

          // 304 with no existing cache is meaningless — must not signal success
          expect(dataSourceMock.isNotModified, false);
          expect(dataSourceMock.isError, false);
          expect(dataSourceMock.isSuccess, false);
        },
      );

      test(
        '304 Not Modified with existing cache should call featuresNotModified()',
        () async {
          // Pre-populate cache with valid feature data
          final cacheData = utf8.encode(MockResponse.successResponse);
          CachingManager().putData(
            fileName: Constant.featureCache,
            content: Uint8List.fromList(cacheData),
          );

          featureViewModel = FeatureViewModel(
            encryptionKey: '',
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(notModified: true),
              context: context,
            ),
          );

          // _expiresAt starts as null → isCacheExpired() == true, so network is always triggered
          await featureViewModel.fetchFeatures(context.getFeaturesURL());

          // Cache was valid AND server confirmed 304 → featuresNotModified should fire
          expect(dataSourceMock.isNotModified, true);
          expect(dataSourceMock.isError, false);
        },
      );

      test(
          'concurrent fetchFeatures calls should only trigger one network call',
          () async {
        featureViewModel = FeatureViewModel(
          encryptionKey: testApiKey,
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const MockNetworkClient(),
            context: context,
          ),
          ttlSeconds: 1,
        );

        final futures = [
          featureViewModel.fetchFeatures(context.getFeaturesURL()),
          featureViewModel.fetchFeatures(context.getFeaturesURL()),
          featureViewModel.fetchFeatures(context.getFeaturesURL()),
        ];

        await Future.wait(futures);

        expect(dataSourceMock.isSuccess, true);
        expect(dataSourceMock.counterNetworkCall, 1);
      });

      test('a forced round does not read and re-apply the cache', () async {
        final cacheData = utf8.encode(MockResponse.successResponse);
        CachingManager().putData(
          fileName: Constant.featureCache,
          content: Uint8List.fromList(cacheData),
        );

        featureViewModel = FeatureViewModel(
          encryptionKey: '',
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const MockNetworkClient(),
            context: context,
          ),
          ttlSeconds: 3600,
        );

        final succeeded = await featureViewModel
            .fetchFeatures(context.getFeaturesURL(), force: true);

        // The in-memory features already mirror the cache, so decoding it and
        // rebuilding the evaluation context before every poll is pure waste.
        expect(succeeded, true);
        expect(dataSourceMock.counterCacheCall, 0);
        expect(dataSourceMock.counterNetworkCall, 1);
      });

      test('a forced call joining an unforced round runs its own', () async {
        featureViewModel = FeatureViewModel(
          encryptionKey: '',
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const MockNetworkClient(),
            context: context,
          ),
          ttlSeconds: 3600,
        );

        final unforced = featureViewModel.fetchFeatures(
          context.getFeaturesURL(),
        );
        final forced = featureViewModel.fetchFeatures(
          context.getFeaturesURL(),
          force: true,
        );
        await Future.wait([unforced, forced]);

        // Taking the unforced round's answer would skip the network whenever
        // the cache happened to be fresh — exactly what force rules out.
        expect(dataSourceMock.counterNetworkCall, 2);
      });

      test('a remote eval failure is reported as a failed round', () async {
        featureViewModel = FeatureViewModel(
          encryptionKey: '',
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const MockNetworkClient(error: true),
            context: context,
          ),
        );

        final succeeded = await featureViewModel.fetchFeatures(
          context.getRemoteEvalUrl(),
          remoteEval: true,
          payload: RemoteEvalModel(
            attributes: const <String, dynamic>{},
            forcedFeatures: const [],
            forcedVariations: const <String, dynamic>{},
          ),
        );

        expect(succeeded, false);
      });

      test('an unusable remote eval payload is a failed round', () async {
        featureViewModel = FeatureViewModel(
          encryptionKey: '',
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const _EmptyPayloadClient(),
            context: context,
          ),
        );

        final succeeded = await featureViewModel.fetchFeatures(
          context.getRemoteEvalUrl(),
          remoteEval: true,
          payload: RemoteEvalModel(
            attributes: const <String, dynamic>{},
            forcedFeatures: const [],
            forcedVariations: const <String, dynamic>{},
          ),
        );

        // Neither features nor encryptedFeatures came back: nothing was
        // applied, so counting the round as a success would reset a caller's
        // failure count and keep its backoff from ever starting.
        expect(succeeded, false);
      });

      test(
        'empty cache should not throw FormatException and should fallback to network',
        () async {
          CachingManager().putData(
            fileName: Constant.featureCache,
            content: Uint8List(0),
          );

          featureViewModel = FeatureViewModel(
            encryptionKey: testApiKey,
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(),
              context: context,
            ),
          );

          await featureViewModel.fetchFeatures(context.getFeaturesURL());

          expect(dataSourceMock.isSuccess, true);
          expect(dataSourceMock.isError, false);
        },
      );

      test(
        'corrupt cache (invalid JSON) should not throw and should fallback to network',
        () async {
          final corruptData = Uint8List.fromList([123, 34]);

          CachingManager().putData(
            fileName: Constant.featureCache,
            content: corruptData,
          );

          featureViewModel = FeatureViewModel(
            encryptionKey: testApiKey,
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(),
              context: context,
            ),
          );

          await featureViewModel.fetchFeatures(context.getFeaturesURL());

          expect(dataSourceMock.isSuccess, true);
          expect(dataSourceMock.isError, false);
        },
      );
    },
  );
}

/// Answers every request with a 200 that carries no definitions at all.
class _EmptyPayloadClient implements BaseClient {
  const _EmptyPayloadClient();

  static const _empty = <String, dynamic>{'status': 200};

  @override
  Future<void> consumeGetRequest(
          String url, OnSuccess onSuccess, OnError onError) async =>
      onSuccess(_empty);

  @override
  Future<void> consumePostRequest(String baseUrl, Map<String, dynamic> params,
          OnSuccess onSuccess, OnError onError) async =>
      onSuccess(_empty);

  @override
  Future<void> consumeSseConnections(
      String url, OnSuccess onSuccess, OnError onError) async {}
}
