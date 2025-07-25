// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experiment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBExperiment _$GBExperimentFromJson(Map<String, dynamic> json) => GBExperiment(
      key: json['key'] as String,
      variations: json['variations'] as List<dynamic>? ?? const [],
      namespace: json['namespace'] as List<dynamic>?,
      condition: json['condition'] as Map<String, dynamic>?,
      parentConditions: (json['parentConditions'] as List<dynamic>?)
          ?.map((e) => GBParentCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
      hashAttribute: json['hashAttribute'] as String?,
      fallbackAttribute: json['fallbackAttribute'] as String?,
      weights: (json['weights'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      active: json['active'] as bool? ?? true,
      coverage: (json['coverage'] as num?)?.toDouble(),
      force: (json['force'] as num?)?.toInt(),
      hashVersion: (json['hashVersion'] as num?)?.toDouble(),
      disableStickyBucketing: json['disableStickyBucketing'] as bool?,
      bucketVersion: (json['bucketVersion'] as num?)?.toInt(),
      minBucketVersion: (json['minBucketVersion'] as num?)?.toInt(),
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
    );

Map<String, dynamic> _$GBExperimentToJson(GBExperiment instance) =>
    <String, dynamic>{
      'key': instance.key,
      'variations': instance.variations,
      'namespace': instance.namespace,
      'hashAttribute': instance.hashAttribute,
      'fallbackAttribute': instance.fallbackAttribute,
      'weights': instance.weights,
      'active': instance.active,
      'coverage': instance.coverage,
      'condition': instance.condition,
      'parentConditions': instance.parentConditions,
      'force': instance.force,
      'hashVersion': instance.hashVersion,
      'disableStickyBucketing': instance.disableStickyBucketing,
      'bucketVersion': instance.bucketVersion,
      'minBucketVersion': instance.minBucketVersion,
      'ranges': instance.ranges,
      'meta': instance.meta,
      'filters': instance.filters,
      'seed': instance.seed,
      'name': instance.name,
      'phase': instance.phase,
    };
