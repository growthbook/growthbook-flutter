import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Features/gb_features_converter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'features_model.g.dart';

@JsonSerializable()
class FeaturedDataModel {
  FeaturedDataModel({
    required this.features,
    required this.encryptedFeatures,
    this.savedGroups,
    this.encryptedSavedGroups,
    this.contextualBandits,
    this.encryptedContextualBandits,
  });

  @GBFeaturesConverter()
  final GBFeatures? features;

  final String? encryptedFeatures;

  final SavedGroupsValues? savedGroups;

  final String? encryptedSavedGroups;

  /// Map of `contextualBanditRef` → raw JSON definition. The SDK deserializes
  /// each entry lazily during evaluation via
  /// [ContextualBanditDefinition.fromJson].
  final Map<String, dynamic>? contextualBandits;

  final String? encryptedContextualBandits;

  factory FeaturedDataModel.fromJson(Map<String, dynamic> json) =>
      _$FeaturedDataModelFromJson(json);

  Map<String, dynamic> toJson() => _$FeaturedDataModelToJson(this);
}
