import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/gb_parent_condition.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_filter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_variation_meta.dart';
import 'package:json_annotation/json_annotation.dart';

part 'experiment.g.dart';

/// Defines a single experiment
@JsonSerializable()
class GBExperiment {
  GBExperiment({
    required this.key,
    this.variations = const [],
    this.namespace,
    this.condition,
    this.parentConditions,
    this.hashAttribute,
    this.fallbackAttribute,
    this.weights,
    this.active = true,
    this.coverage,
    this.force,
    this.hashVersion,
    this.disableStickyBucketing,
    this.bucketVersion,
    this.minBucketVersion,
    this.ranges,
    this.meta,
    this.filters,
    this.seed,
    this.name,
    this.phase,
  });

  /// The globally unique tracking key for the experiment
  String key;

  /// The different variations to choose between
  List variations = [];

  /// A tuple that contains the namespace identifier, plus a range of coverage for the experiment
  List? namespace;

  /// All users included in the experiment will be forced into the specific variation index
  String? hashAttribute;

  /// When using sticky bucketing, can be used as a fallback to assign variations
  String? fallbackAttribute;

  /// How to weight traffic between variations. Must add to 1.
  List<double>? weights;

  /// If set to false, always return the control (first variation)
  bool active;

  /// What percent of users should be included in the experiment (between 0 and 1, inclusive)
  double? coverage;

  /// Optional targeting condition
  GBCondition? condition;

  // Each item defines a prerequisite where a condition must evaluate against a parent feature's
  // value (identified by id). If gate is true, then this is a blocking feature-level prerequisite;
  // otherwise it applies to the current rule only.
  List<GBParentCondition>? parentConditions;

  /// All users included in the experiment will be forced into the specific variation index
  int? force;

  ///Check if experiment is not active.
  bool get deactivated => !active;

  //new properties v0.4.0
  /// The hash version to use (default to 1)
  double? hashVersion;

  /// If true, sticky bucketing will be disabled for this experiment. (Note: sticky bucketing is only available if a StickyBucketingService is provided in the Context)
  bool? disableStickyBucketing;

  /// An sticky bucket version number that can be used to force a re-bucketing of users (default to `0`)
  int? bucketVersion;

  /// Any users with a sticky bucket version less than this will be excluded from the experiment
  int? minBucketVersion;

  /// Array of ranges, one per variation
  // @Tuple2Converter()
  List<GBBucketRange>? ranges;

  /// Meta info about the variations
  List<GBVariationMeta>? meta;

  /// Array of filters to apply
  List<GBFilter>? filters;

  /// The hash seed to use
  String? seed;

  /// Human-readable name for the experiment
  String? name;

  /// Id of the current experiment phase
  String? phase;

  factory GBExperiment.fromJson(Map<String, dynamic> value) =>
      _$GBExperimentFromJson(value);

  Map<String, dynamic> toJson() => _$GBExperimentToJson(this);
}
