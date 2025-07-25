// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gb_parent_condition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBParentCondition _$GBParentConditionFromJson(Map<String, dynamic> json) =>
    GBParentCondition(
      id: json['id'] as String,
      condition: json['condition'] as Map<String, dynamic>,
      gate: json['gate'] as bool?,
    );

Map<String, dynamic> _$GBParentConditionToJson(GBParentCondition instance) =>
    <String, dynamic>{
      'id': instance.id,
      'condition': instance.condition,
      'gate': instance.gate,
    };
