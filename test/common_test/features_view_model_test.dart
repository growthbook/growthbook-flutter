import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
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
    },
  );
}
