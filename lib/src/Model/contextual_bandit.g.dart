// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contextual_bandit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContextualBanditContext _$ContextualBanditContextFromJson(
        Map<String, dynamic> json) =>
    ContextualBanditContext(
      leafId: (json['leafId'] as num?)?.toInt(),
      condition: json['condition'] as Map<String, dynamic>?,
      weights: (json['weights'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );

Map<String, dynamic> _$ContextualBanditContextToJson(
        ContextualBanditContext instance) =>
    <String, dynamic>{
      'leafId': instance.leafId,
      'condition': instance.condition,
      'weights': instance.weights,
    };

ContextualBanditDefinition _$ContextualBanditDefinitionFromJson(
        Map<String, dynamic> json) =>
    ContextualBanditDefinition(
      banditVersion: (json['banditVersion'] as num?)?.toInt(),
      contexts: (json['contexts'] as List<dynamic>?)
          ?.map((e) =>
              ContextualBanditContext.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ContextualBanditDefinitionToJson(
        ContextualBanditDefinition instance) =>
    <String, dynamic>{
      'banditVersion': instance.banditVersion,
      'contexts': instance.contexts,
    };
