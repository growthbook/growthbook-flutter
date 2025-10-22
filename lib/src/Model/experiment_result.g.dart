// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experiment_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBExperimentResult _$GBExperimentResultFromJson(Map<String, dynamic> json) =>
    GBExperimentResult(
      bucket: (json['bucket'] as num?)?.toDouble(),
      featureId: json['featureId'] as String?,
      hashAttribute: json['hashAttribute'] as String?,
      hashUsed: json['hashUsed'] as bool?,
      hashValue: json['hashValue'] as String?,
      inExperiment: json['inExperiment'] as bool,
      key: json['key'] as String,
      stickyBucketUsed: json['stickyBucketUsed'] as bool?,
      value: json['value'],
      variationID: (json['variationID'] as num?)?.toInt(),
      name: json['name'] as String?,
      passthrough: json['passthrough'] as bool?,
    );

Map<String, dynamic> _$GBExperimentResultToJson(GBExperimentResult instance) =>
    <String, dynamic>{
      'bucket': instance.bucket,
      'featureId': instance.featureId,
      'hashAttribute': instance.hashAttribute,
      'hashUsed': instance.hashUsed,
      'hashValue': instance.hashValue,
      'inExperiment': instance.inExperiment,
      'key': instance.key,
      'stickyBucketUsed': instance.stickyBucketUsed,
      'value': instance.value,
      'variationID': instance.variationID,
      'name': instance.name,
      'passthrough': instance.passthrough,
    };
