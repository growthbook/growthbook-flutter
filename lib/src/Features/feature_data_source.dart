import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/Utils/feature_url_builder.dart';

typedef FeatureFetchSuccessCallBack = void Function(
  FeaturedDataModel featuredDataModel,
);

abstract class FeaturesFlowDelegate {
  void featuresFetchedSuccessfully(
      {required GBFeatures gbFeatures, required bool isRemote});
  void featuresAPIModelSuccessfully(FeaturedDataModel model);
  void featuresFetchFailed({required GBError? error, required bool isRemote});
  void savedGroupsFetchedSuccessfully(
      {required SavedGroupsValues savedGroups, required bool isRemote});
  void savedGroupsFetchFailed(
      {required GBError? error, required bool isRemote});
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
    featureRefreshStrategy == FeatureRefreshStrategy.SERVER_SENT_EVENTS
        ? await client.consumeSseConnections(
            _getEndpoint(
                context: context,
                featureRefreshStrategy: featureRefreshStrategy),
            (response) => onSuccess(
              FeaturedDataModel.fromJson(response),
            ),
            onError,
          )
        : await client.consumeGetRequest(
            _getEndpoint(
                context: context,
                featureRefreshStrategy: featureRefreshStrategy),
            (response) => onSuccess(
              FeaturedDataModel.fromJson(response),
            ),
            onError,
          );
  }

  Future<void> fetchRemoteEval({
    required RemoteEvalModel? params,
    required FeatureFetchSuccessCallBack onSuccess,
    required OnError onError,
  }) async {
    final remoteEvalJson = RemoteEvalModel(
      attributes: params?.attributes,
      forcedFeatures: params?.forcedFeatures,
      forcedVariations: params?.forcedVariations,
    ).toJson();

    await client.consumePostRequest(
      _getEndpoint(
        context: context,
        featureRefreshStrategy:
            FeatureRefreshStrategy.SERVER_SENT_REMOTE_FEATURE_EVAL,
      ),
      remoteEvalJson,
      (response) => onSuccess(
        FeaturedDataModel.fromJson(response),
      ),
      onError,
    );
  }

  String _getEndpoint(
      {required GBContext context,
      FeatureRefreshStrategy featureRefreshStrategy =
          FeatureRefreshStrategy.STALE_WHILE_REVALIDATE}) {
    return FeatureURLBuilder(
            apiHost: context.apiHost, streamingHost: context.streamingHost)
        .buildUrl(context.apiKey,
            featureRefreshStrategy: featureRefreshStrategy);
  }
}
