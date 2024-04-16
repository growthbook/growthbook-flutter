import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

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
            trackingCallBack: (_, __) {},
          );
          dataSourceMock = DataSourceMock();
          featureViewModel = FeatureViewModel(
            encryptionKey: testApiKey,
            delegate: dataSourceMock,
            source: FeatureDataSource(
              client: const MockNetworkClient(),
              context: context,
            ),
          );
        },
      );
      test(
        'success feature-view model.',
        () async {
          await featureViewModel.fetchFeature();
          expect(dataSourceMock.isSuccess, true);
        },
      );
    },
  );
}
