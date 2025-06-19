import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

class GBFeaturesConverter extends JsonConverter<GBFeatures, Map<String, dynamic>> {
  const GBFeaturesConverter();

  @override
  GBFeatures fromJson(Map<String, dynamic> json) {
    final result = <String, GBFeature>{};
    json.forEach((key, value) {
      if (value != null && value is Map<String, dynamic>) {
        result[key] = GBFeature.fromJson(value);
      }
    });
    return result;
  }

  @override
  Map<String, dynamic> toJson(GBFeatures object) {
    return object.map((key, value) => MapEntry(key, value.toJson()));
  }
}
