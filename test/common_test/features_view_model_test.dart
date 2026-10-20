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

      /// Remote-eval mode is set by supplying a request provider, so tests build
      /// the same request the SDK would build for the current context.
      RemoteEvalRequest remoteEvalRequest() {
        return RemoteEvalRequest(
          apiUrl: '',
          payload: RemoteEvalModel(
            attributes: <String, dynamic>{},
            forcedFeatures: [
              ['feature', 123]
            ],
            forcedVariations: {'feature': 123},
          ),
        );
      }

      test('Remote eval success test with a request provider', () async {
        featureViewModel = FeatureViewModel(
          encryptionKey: '',
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const MockNetworkClient(),
            context: context,
          ),
          remoteEvalRequestProvider: remoteEvalRequest,
        );

        await featureViewModel.fetchFeatures('');

        expect(dataSourceMock.isSuccess, true);
      });

      /// The cached payload was evaluated for the inputs of an earlier round, so
      /// replaying it once the SDK is running would surface features that do not
      /// match the current attributes.
      test('remote eval serves the cache only on the first round', () async {
        final delegate = _CacheServeCountingDelegate();
        featureViewModel = FeatureViewModel(
          encryptionKey: '',
          delegate: delegate,
          source: FeatureDataSource(
            client: const MockNetworkClient(),
            context: context,
          ),
          remoteEvalRequestProvider: remoteEvalRequest,
        );

        // First round populates the cache from the response.
        await featureViewModel.fetchFeatures('');
        delegate.cachedServes = 0;

        await featureViewModel.fetchFeatures('');

        expect(delegate.cachedServes, 0);
        expect(delegate.remoteServes, greaterThan(0));
      });

      /// A client that throws instead of calling onError must not leave the
      /// failure unreported.
      test('a remote-eval client that throws is reported as a failure',
          () async {
        featureViewModel = FeatureViewModel(
          encryptionKey: '',
          delegate: dataSourceMock,
          source: FeatureDataSource(
            client: const _ThrowingNetworkClient(),
            context: context,
          ),
          remoteEvalRequestProvider: remoteEvalRequest,
        );

        await featureViewModel.fetchFeatures('');

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

/// Delegate that tells apart features served from cache and from the network.
class _CacheServeCountingDelegate extends DataSourceMock {
  int cachedServes = 0;
  int remoteServes = 0;

  @override
  void featuresFetchedSuccessfully(
      {required GBFeatures gbFeatures, required bool isRemote}) {
    isRemote ? remoteServes++ : cachedServes++;
    super.featuresFetchedSuccessfully(
        gbFeatures: gbFeatures, isRemote: isRemote);
  }
}

/// Client whose remote-eval POST throws instead of calling onError.
class _ThrowingNetworkClient extends MockNetworkClient {
  const _ThrowingNetworkClient();

  @override
  Future<void> consumePostRequest(String baseUrl, Map<String, dynamic> params,
      OnSuccess onSuccess, OnError onError) async {
    throw StateError('send failed');
  }
}
