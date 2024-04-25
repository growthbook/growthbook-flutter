import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'gb_filter.g.dart';

/// Object used for mutual exclusion and filtering users out of experiments based on random hashes
@JsonSerializable()
class GBFilter {
  GBFilter({
    required this.seed,
    required this.ranges,
    required this.attribute,
    this.hashVersion = 2,
  });

  final String seed;

  final List<GBBucketRange> ranges;

  final String? attribute;

  final int hashVersion;

  factory GBFilter.fromJson(Map<String, dynamic> value) =>
      _$GBFilterFromJson(value);

  Map<String, dynamic> toJson() => _$GBFilterToJson(this);
}
