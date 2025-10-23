// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gb_variation_meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBVariationMeta _$GBVariationMetaFromJson(Map<String, dynamic> json) =>
    GBVariationMeta(
      key: json['key'] as String?,
      name: json['name'] as String?,
      passthrough: json['passthrough'] as bool?,
    );

Map<String, dynamic> _$GBVariationMetaToJson(GBVariationMeta instance) =>
    <String, dynamic>{
      'key': instance.key,
      'name': instance.name,
      'passthrough': instance.passthrough,
    };

GBTrack _$GBTrackFromJson(Map<String, dynamic> json) => GBTrack(
      experiment: json['experiment'] == null
          ? null
          : GBExperiment.fromJson(json['experiment'] as Map<String, dynamic>),
      featureResult: json['featureResult'] == null
          ? null
          : GBFeatureResult.fromJson(
              json['featureResult'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GBTrackToJson(GBTrack instance) => <String, dynamic>{
      'experiment': instance.experiment,
      'featureResult': instance.featureResult,
    };
