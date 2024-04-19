import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/feature_url_builder.dart';

typedef FeatureFetchSuccessCallBack = void Function(
  FeaturedDataModel featuredDataModel,
);

abstract class FeaturesFlowDelegate {
  void featuresFetchedSuccessfully(GBFeatures gbFeatures);
  void featuresFetchFailed(GBError? error);
}

class FeatureDataSource {
  FeatureDataSource({
    required this.context,
    required this.client,
  });
  final GBContext context;
  final BaseClient client;

  Future<void> fetchFeatures(
    FeatureFetchSuccessCallBack onSuccess,
    OnError onError, {
    FeatureRefreshStrategy featureRefreshStrategy =
        FeatureRefreshStrategy.STALE_WHILE_REVALIDATE,
  }) async {
    final apiSse = FeatureURLBuilder.buildUrl(context.apiKey ?? "",
        featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS);

    featureRefreshStrategy == FeatureRefreshStrategy.SERVER_SENT_EVENTS
        ? await client.consumeSseConnections(
            context.hostURL!,
            apiSse,
            (response) => onSuccess(
              FeaturedDataModel.fromJson(response),
            ),
            onError,
          )
        : await client.consumeGetRequest(
            context.hostURL ?? "",
            FeatureURLBuilder.buildUrl(context.apiKey ?? ""),
            (response) => onSuccess(
              FeaturedDataModel.fromJson(response),
            ),
            onError,
          );
  }
}
