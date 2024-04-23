// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'features_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeaturedDataModel _$FeaturedDataModelFromJson(Map<String, dynamic> json) =>
    FeaturedDataModel(
      features: const GBFeaturesConverter()
          .fromJson(json['features'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FeaturedDataModelToJson(FeaturedDataModel instance) =>
    <String, dynamic>{
      'features': const GBFeaturesConverter().toJson(instance.features),
    };
