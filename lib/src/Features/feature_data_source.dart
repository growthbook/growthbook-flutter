import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

abstract class FeaturesFlowDelegate {
  void featuresFetchedSuccessfully(GBFeatures gbFeatures);
}

class FeatureDataSource {
  FeatureDataSource(
      {required this.context, required this.client, required this.onError});
  final GBContext context;
  final BaseClient client;
  final OnError onError;

  Future<FeaturedDataModel> fetchFeatures() async {
    final api = context.hostURL! + Constant.featurePath + context.apiKey!;
    await client.consumeGetRequest(api, onSuccess, onError);
    setUpModel();
    return model;
  }

  late FeaturedDataModel model;
  late Map<String, dynamic> data;

  /// Assign response to local variable [data]
  void onSuccess(response) {
    data = response;
  }

  /// Initialize [model] from the [data]
  void setUpModel() {
    model = FeaturedDataModel.fromJson(data);
  }
}
