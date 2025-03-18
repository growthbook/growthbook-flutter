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

Map<String, dynamic> _$GBFeatureToJson(GBFeature instance) => <String, dynamic>{
      'rules': instance.rules,
      'defaultValue': instance.defaultValue,
    };

GBFeatureRule _$GBFeatureRuleFromJson(Map<String, dynamic> json) =>
    GBFeatureRule(
      id: json['id'] as String? ?? "",
      condition: json['condition'] as Map<String, dynamic>?,
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
      hashVersion: (json['hashVersion'] as num?)?.toInt(),
      disableStickyBucketing: json['disableStickyBucketing'] as bool?,
      bucketVersion: (json['bucketVersion'] as num?)?.toInt(),
      minBucketVersion: (json['minBucketVersion'] as num?)?.toInt(),
      range: (json['range'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      ranges: (json['ranges'] as List<dynamic>?)
          ?.map((e) =>
              (e as List<dynamic>).map((e) => (e as num).toDouble()).toList())
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
      tracks: (json['tracks'] as List<dynamic>?)
          ?.map((e) => GBTrack.fromJson(e as Map<String, dynamic>))
          .toList(),
      parentConditions: (json['parentConditions'] as List<dynamic>?)
          ?.map((e) => GBParentCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GBFeatureRuleToJson(GBFeatureRule instance) =>
    <String, dynamic>{
      'id': instance.id,
      'condition': instance.condition,
      'parentConditions': instance.parentConditions,
      'coverage': instance.coverage,
      'force': instance.force,
      'variations': instance.variations,
      'key': instance.key,
      'weights': instance.weights,
      'namespace': instance.namespace,
      'hashAttribute': instance.hashAttribute,
      'fallbackAttribute': instance.fallbackAttribute,
      'hashVersion': instance.hashVersion,
      'disableStickyBucketing': instance.disableStickyBucketing,
      'bucketVersion': instance.bucketVersion,
      'minBucketVersion': instance.minBucketVersion,
      'range': instance.range,
      'ranges': instance.ranges,
      'meta': instance.meta,
      'filters': instance.filters,
      'seed': instance.seed,
      'name': instance.name,
      'phase': instance.phase,
      'tracks': instance.tracks,
    };

GBFeatureResult _$GBFeatureResultFromJson(Map<String, dynamic> json) =>
    GBFeatureResult(
      value: json['value'],
      on: json['on'] as bool? ?? false,
      off: json['off'] as bool? ?? true,
      source: $enumDecodeNullable(_$GBFeatureSourceEnumMap, json['source']),
      experiment: json['experiment'] == null
          ? null
          : GBExperiment.fromJson(json['experiment'] as Map<String, dynamic>),
      experimentResult: json['experimentResult'] == null
          ? null
          : GBExperimentResult.fromJson(
              json['experimentResult'] as Map<String, dynamic>),
      ruleId: json['ruleId'] as String? ?? "",
    );

Map<String, dynamic> _$GBFeatureResultToJson(GBFeatureResult instance) =>
    <String, dynamic>{
      'value': instance.value,
      'on': instance.on,
      'off': instance.off,
      'source': _$GBFeatureSourceEnumMap[instance.source],
      'experiment': instance.experiment,
      'experimentResult': instance.experimentResult,
      'ruleId': instance.ruleId,
    };

const _$GBFeatureSourceEnumMap = {
  GBFeatureSource.unknownFeature: 'unknownFeature',
  GBFeatureSource.defaultValue: 'defaultValue',
  GBFeatureSource.force: 'force',
  GBFeatureSource.experiment: 'experiment',
  GBFeatureSource.cyclicPrerequisite: 'cyclicPrerequisite',
  GBFeatureSource.prerequisite: 'prerequisite',
};
