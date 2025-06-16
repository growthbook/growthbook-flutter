import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

class GBFeaturesConverter
    extends JsonConverter<GBFeatures, Map<String, dynamic>> {
  const GBFeaturesConverter();

  @override
  GBFeatures fromJson(Map<String, dynamic> json) {
    return json.map((key, value) {
      return MapEntry(key, GBFeature.fromJson(value));
    });
  }

  @override
  Map<String, dynamic> toJson(GBFeatures object) {
    Map<String, dynamic> featureMap = {};
    object.forEach((key, value) {
      featureMap[key] = value.toJson();
    });
    return featureMap;
  }
}
