// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'constant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBFilter _$GBFilterFromJson(Map<String, dynamic> json) => GBFilter(
      seed: json['seed'] as String,
      ranges: (json['ranges'] as List<dynamic>)
          .map((e) =>
              (e as List<dynamic>).map((e) => (e as num).toDouble()).toList())
          .toList(),
      attribute: json['attribute'] as String?,
      hashVersion: json['hashVersion'] as int? ?? 2,
    );

Map<String, dynamic> _$GBFilterToJson(GBFilter instance) => <String, dynamic>{
      'seed': instance.seed,
      'ranges': instance.ranges,
      'attribute': instance.attribute,
      'hashVersion': instance.hashVersion,
    };

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
