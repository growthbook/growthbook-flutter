// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_eval_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RemoteEvalModel _$RemoteEvalModelFromJson(Map<String, dynamic> json) =>
    RemoteEvalModel(
      attributes: json['attributes'] as Map<String, dynamic>?,
      forcedFeatures: json['forcedFeatures'] as List<dynamic>?,
      forcedVariations: json['forcedVariations'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$RemoteEvalModelToJson(RemoteEvalModel instance) =>
    <String, dynamic>{
      'attributes': instance.attributes,
      'forcedFeatures': instance.forcedFeatures,
      'forcedVariations': instance.forcedVariations,
    };
