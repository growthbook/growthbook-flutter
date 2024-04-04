// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experiment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBExperiment _$GBExperimentFromJson(Map<String, dynamic> json) => GBExperiment(
      key: json['key'] as String?,
      variations: json['variations'] as List<dynamic>? ?? const [],
      namespace: json['namespace'] as List<dynamic>?,
      condition: json['condition'],
      parentConditions: (json['parentConditions'] as List<dynamic>?)
          ?.map((e) => GBParentCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
      hashAttribute: json['hashAttribute'] as String?,
      fallbackAttribute: json['fallbackAttribute'] as String?,
      weights: json['weights'] as List<dynamic>?,
      active: json['active'] as bool? ?? true,
      coverage: (json['coverage'] as num?)?.toDouble(),
      force: json['force'] as int?,
      hashVersion: json['hashVersion'] as int?,
      disableStickyBucketing: json['disableStickyBucketing'] as bool?,
      bucketVersion: json['bucketVersion'] as int?,
      minBucketVersion: json['minBucketVersion'] as int?,
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
    );

GBExperimentResult _$GBExperimentResultFromJson(Map<String, dynamic> json) =>
    GBExperimentResult(
      inExperiment: json['inExperiment'] as bool?,
      variationID: json['variationID'] as int?,
      value: json['value'],
      hashUsed: json['hashUsed'] as bool?,
      hasAttributes: json['hasAttributes'] as String?,
      hashValue: json['hashValue'] as String?,
      featureId: json['featureId'] as String?,
      key: json['key'] as String?,
      name: json['name'] as String?,
      bucket: (json['bucket'] as num?)?.toDouble(),
      passthrough: json['passthrough'] as bool?,
      stickyBucketUsed: json['stickyBucketUsed'] as bool?,
    );
