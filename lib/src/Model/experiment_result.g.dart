// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experiment_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBExperimentResult _$GBExperimentResultFromJson(Map<String, dynamic> json) =>
    GBExperimentResult(
      inExperiment: json['inExperiment'] as bool,
      variationID: (json['variationID'] as num?)?.toInt(),
      value: json['value'],
      hashUsed: json['hashUsed'] as bool?,
      hashAttribute: json['hashAttribute'] as String?,
      hashValue: json['hashValue'] as String?,
      featureId: json['featureId'] as String?,
      key: json['key'] as String,
      name: json['name'] as String?,
      bucket: (json['bucket'] as num?)?.toDouble(),
      passthrough: json['passthrough'] as bool?,
      stickyBucketUsed: json['stickyBucketUsed'] as bool?,
    );

Map<String, dynamic> _$GBExperimentResultToJson(GBExperimentResult instance) =>
    <String, dynamic>{
      'inExperiment': instance.inExperiment,
      'variationID': instance.variationID,
      'value': instance.value,
      'hashUsed': instance.hashUsed,
      'hashAttribute': instance.hashAttribute,
      'hashValue': instance.hashValue,
      'featureId': instance.featureId,
      'key': instance.key,
      'name': instance.name,
      'bucket': instance.bucket,
      'passthrough': instance.passthrough,
      'stickyBucketUsed': instance.stickyBucketUsed,
    };
