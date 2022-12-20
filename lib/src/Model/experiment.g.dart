// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experiment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBExperiment _$GBExperimentFromJson(Map<String, dynamic> json) => GBExperiment(
      key: json['key'] as String?,
      variations: json['variations'] as List<dynamic>?,
      namespace: json['namespace'] as List<dynamic>?,
      condition: json['condition'],
      hashAttribute: json['hashAttribute'] as String?,
      weights: json['weights'] as List<dynamic>?,
      active: json['active'] as bool? ?? true,
      coverage: (json['coverage'] as num?)?.toDouble(),
      force: json['force'] as int?,
    );
