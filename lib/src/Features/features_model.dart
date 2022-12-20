import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'features_model.g.dart';

@JsonSerializable(createToJson: false)
class FeaturedDataModel {
  FeaturedDataModel({required this.features});

  @GBFeaturesConverter()
  final GBFeatures features;

  factory FeaturedDataModel.fromJson(Map<String, dynamic> json) =>
      _$FeaturedDataModelFromJson(json);
}
