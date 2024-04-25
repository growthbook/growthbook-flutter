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

GBTrackData _$GBTrackDataFromJson(Map<String, dynamic> json) => GBTrackData(
      experiment:
          GBExperiment.fromJson(json['experiment'] as Map<String, dynamic>),
      experimentResult: GBExperimentResult.fromJson(
          json['experimentResult'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GBTrackDataToJson(GBTrackData instance) =>
    <String, dynamic>{
      'experiment': instance.experiment,
      'experimentResult': instance.experimentResult,
    };
