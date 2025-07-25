// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gb_filter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GBFilter _$GBFilterFromJson(Map<String, dynamic> json) => GBFilter(
      seed: json['seed'] as String,
      ranges: (json['ranges'] as List<dynamic>)
          .map((e) =>
              (e as List<dynamic>).map((e) => (e as num).toDouble()).toList())
          .toList(),
      attribute: json['attribute'] as String?,
      hashVersion: (json['hashVersion'] as num?)?.toInt() ?? 2,
    );

Map<String, dynamic> _$GBFilterToJson(GBFilter instance) => <String, dynamic>{
      'seed': instance.seed,
      'ranges': instance.ranges,
      'attribute': instance.attribute,
      'hashVersion': instance.hashVersion,
    };
