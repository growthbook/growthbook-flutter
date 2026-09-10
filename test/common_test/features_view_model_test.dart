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

      /// Remote-eval mode is set by supplying a request provider, so tests build
      /// the same request the SDK would build for the current context.
      RemoteEvalRequest remoteEvalRequest() {
        final forcedFeature = {'feature': 123};
        final forcedVariation = {'feature': 123};
        final attributes = <String, dynamic>{};
        return RemoteEvalRequest(
          apiUrl: '',
          payload: RemoteEvalModel(
            attributes: attributes,
            forcedFeatures: forcedFeature.entries
                .map((entry) => [entry.key, entry.value])
                .toList(),
            forcedVariations: forcedVariation,
          ),
        );
      }

      test('Remote eval success test', () async {
        featureViewModel = FeatureViewModel(
          encryptionKey: testApiKey,
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
          remoteEvalRequestProvider: remoteEvalRequest,
        );

        await featureViewModel.fetchFeatures('');

        expect(dataSourceMock.isError, true);
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

      /// Two SDK connections serve different payloads, so they must not share a
      /// cache entry: one would overwrite the other and then read it back as its
      /// own.
      group('cache namespacing', () {
        FeatureViewModel viewModelFor(GBContext ctx) {
          return FeatureViewModel(
            encryptionKey: '',
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(),
              context: ctx,
            ),
          );
        }

        GBContext contextWith({String? apiKey, String? hostURL}) {
          return GBContext(
            apiKey: apiKey ?? testApiKey,
            hostURL: hostURL ?? testHostURL,
            attributes: attr,
            enabled: true,
            forcedVariation: {},
            qaMode: false,
            trackingCallBack: (_) {},
          );
        }

        test('differs per client key', () {
          expect(
            viewModelFor(contextWith(apiKey: 'key-a')).featureCacheFileName,
            isNot(viewModelFor(contextWith(apiKey: 'key-b'))
                .featureCacheFileName),
          );
        });

        test('differs per host', () {
          expect(
            viewModelFor(contextWith(hostURL: 'https://a.example.com'))
                .featureCacheFileName,
            isNot(viewModelFor(contextWith(hostURL: 'https://b.example.com'))
                .featureCacheFileName),
          );
        });

        test('is stable for the same connection', () {
          expect(
            viewModelFor(contextWith()).featureCacheFileName,
            viewModelFor(contextWith()).featureCacheFileName,
          );
        });

        test('keeps features and saved groups in separate entries', () {
          final vm = viewModelFor(contextWith());
          expect(vm.featureCacheFileName, isNot(vm.savedGroupsCacheFileName));
        });

        test('does not spell out the client key', () {
          const key = 'sdk-secret-key';
          expect(
            viewModelFor(contextWith(apiKey: key)).featureCacheFileName,
            isNot(contains(key)),
          );
        });

        /// The actual collision: what one connection cached must not be served
        /// to another.
        test('a payload cached by one connection is not served to another',
            () async {
          final first = viewModelFor(contextWith(apiKey: 'key-a'));
          final second = viewModelFor(contextWith(apiKey: 'key-b'));

          CachingManager().putData(
            fileName: first.featureCacheFileName,
            content:
                Uint8List.fromList(utf8.encode(MockResponse.successResponse)),
          );

          final servedToSecond = await CachingManager()
              .getContent(fileName: second.featureCacheFileName);

          expect(servedToSecond, isNull);
        });
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
          featureViewModel = FeatureViewModel(
            encryptionKey: '',
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(notModified: true),
              context: context,
            ),
          );

          // Pre-populate the cache this view model reads from: the entry is
          // namespaced per SDK connection.
          final cacheData = utf8.encode(MockResponse.successResponse);
          CachingManager().putData(
            fileName: featureViewModel.featureCacheFileName,
            content: Uint8List.fromList(cacheData),
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
          featureViewModel = FeatureViewModel(
            encryptionKey: testApiKey,
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(),
              context: context,
            ),
          );

          CachingManager().putData(
            fileName: featureViewModel.featureCacheFileName,
            content: Uint8List(0),
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

          featureViewModel = FeatureViewModel(
            encryptionKey: testApiKey,
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(),
              context: context,
            ),
          );

          CachingManager().putData(
            fileName: featureViewModel.featureCacheFileName,
            content: corruptData,
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
