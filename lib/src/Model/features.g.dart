// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'features.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBFeature _$GBFeatureFromJson(Map<String, dynamic> json) => GBFeature(
      rules: (json['rules'] as List<dynamic>?)
          ?.map((e) => GBFeatureRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultValue: json['defaultValue'],
    );

GBFeatureRule _$GBFeatureRuleFromJson(Map<String, dynamic> json) =>
    GBFeatureRule(
      condition: json['condition'],
      coverage: (json['coverage'] as num?)?.toDouble(),
      force: json['force'],
      variations: json['variations'] as List<dynamic>?,
      key: json['key'] as String?,
      weights: (json['weights'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      namespace: json['namespace'] as List<dynamic>?,
      hashAttribute: json['hashAttribute'] as String?,
      fallbackAttribute: json['fallbackAttribute'] as String?,
      hashVersion: json['hashVersion'] as int?,
      disableStickyBucketing: json['disableStickyBucketing'] as bool?,
      bucketVersion: json['bucketVersion'] as int?,
      minBucketVersion: json['minBucketVersion'] as int?,
      range:
          _$JsonConverterFromJson<Map<String, dynamic>, Tuple2<double, double>>(
              json['range'], const Tuple2Converter().fromJson),
      ranges: (json['ranges'] as List<dynamic>?)
          ?.map((e) =>
              const Tuple2Converter().fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: (json['meta'] as List<dynamic>?)
          ?.map((e) => GBVariationMeta.fromJson(e as Map<String, dynamic>))
          .toList(),
      filters: (json['filters'] as List<dynamic>?)
          ?.map((e) => GBFilter.fromJson(e as Map<String, dynamic>))
          .toList(),
      seed: json['seed'] as String?,
      name: json['name'] as String?,
      phase: json['phase'] as String?,
      tracks: json['tracks'] == null
          ? null
          : GBTrackData.fromJson(json['tracks'] as Map<String, dynamic>),
      parentConditions: (json['parentConditions'] as List<dynamic>?)
          ?.map((e) => GBParentCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
