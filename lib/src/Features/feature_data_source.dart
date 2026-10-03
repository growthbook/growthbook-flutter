import 'dart:async';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/Utils/feature_url_builder.dart';

typedef FeatureFetchSuccessCallBack = Future<void> Function(
  FeaturedDataModel featuredDataModel,
);

abstract class FeaturesFlowDelegate {
  void featuresFetchedSuccessfully(
      {required GBFeatures gbFeatures, required bool isRemote});
  FutureOr<void> featuresAPIModelSuccessfully(FeaturedDataModel model);
  void featuresFetchFailed({required GBError? error, required bool isRemote});
  void featuresNotModified();
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
            (response) async => onSuccess(
              FeaturedDataModel.fromJson(response),
            ),
            onError,
            headers: context.streamingHostRequestHeaders,
          )
        : await client.consumeGetRequest(
            _getEndpoint(
                context: context,
                featureRefreshStrategy: featureRefreshStrategy),
            (response) async => onSuccess(
              FeaturedDataModel.fromJson(response),
            ),
            onError,
            headers: context.apiHostRequestHeaders,
          );
  }

  Future<void> fetchRemoteEval({
    required String apiUrl,
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
      apiUrl,
      remoteEvalJson,
      (response) async => onSuccess(
        FeaturedDataModel.fromJson(response),
      ),
      onError,
      // Remote evaluation runs against the API host, so it carries the same
      // headers as the features request.
      headers: context.apiHostRequestHeaders,
    );
  }

  String _getEndpoint(
      {required GBContext context,
      FeatureRefreshStrategy featureRefreshStrategy =
          FeatureRefreshStrategy.STALE_WHILE_REVALIDATE}) {
    final url =
        featureRefreshStrategy == FeatureRefreshStrategy.SERVER_SENT_EVENTS
            ? context.getStreamingURL()
            : context.getFeaturesURL();
    // A missing host or client key is a configuration error the SDK cannot
    // recover from here; the empty URL surfaces it as a request failure.
    return url ?? '';
  }
}
