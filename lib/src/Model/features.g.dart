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
    );
