// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'features_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeaturedDataModel _$FeaturedDataModelFromJson(Map<String, dynamic> json) =>
    FeaturedDataModel(
      features:
          _$JsonConverterFromJson<Map<String, dynamic>, Map<String, GBFeature>>(
              json['features'], const GBFeaturesConverter().fromJson),
      encryptedFeatures: json['encryptedFeatures'] as String?,
    );

Map<String, dynamic> _$FeaturedDataModelToJson(FeaturedDataModel instance) =>
    <String, dynamic>{
      'features':
          _$JsonConverterToJson<Map<String, dynamic>, Map<String, GBFeature>>(
              instance.features, const GBFeaturesConverter().toJson),
      'encryptedFeatures': instance.encryptedFeatures,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) =>
    value == null ? null : toJson(value);
