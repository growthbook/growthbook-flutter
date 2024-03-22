// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'constant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBFilter _$GBFilterFromJson(Map<String, dynamic> json) => GBFilter(
      seed: json['seed'] as String,
      ranges: (json['ranges'] as List<dynamic>)
          .map((e) =>
              const Tuple2Converter().fromJson(e as Map<String, dynamic>))
          .toList(),
      attribute: json['attribute'] as String?,
      hashVersion: json['hashVersion'] as int?,
    );

GBVariationMeta _$GBVariationMetaFromJson(Map<String, dynamic> json) =>
    GBVariationMeta(
      key: json['key'] as String?,
      name: json['name'] as String?,
      passthrough: json['passthrough'] as bool?,
    );

GBTrackData _$GBTrackDataFromJson(Map<String, dynamic> json) => GBTrackData(
      experiment:
          GBExperiment.fromJson(json['experiment'] as Map<String, dynamic>),
      experimentResult: GBExperimentResult.fromJson(
          json['experimentResult'] as Map<String, dynamic>),
    );
