import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/gb_parent_condition.dart';
import 'package:json_annotation/json_annotation.dart';

part 'experiment.g.dart';

/// Defines a single experiment
@JsonSerializable(createToJson: false)
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
}

/// The result of running an Experiment given a specific Context
@JsonSerializable(createToJson: false)
class GBExperimentResult {
  GBExperimentResult({
    required this.inExperiment,
    this.variationID,
    this.value,
    this.hashUsed,
    this.hashAttribute,
    this.hashValue,
    this.featureId,
    required this.key,
    this.name,
    this.bucket,
    this.passthrough,
    this.stickyBucketUsed,
  });

  /// Whether or not the user is part of the experiment
  bool inExperiment;

  /// The array index of the assigned variation
  int? variationID;

  /// The array value of the assigned variation
  dynamic value;

  /// If a hash was used to assign a variation
  bool? hashUsed;

  /// The user attribute used to assign a variation
  String? hashAttribute;

  /// The value of that attribute
  String? hashValue;

  /// The id of the feature (if any) that the experiment came from
  String? featureId;

  //new properties v0.4.0
  /// The unique key for the assigned variation
  String key;

  /// The human-readable name of the assigned variation
  String? name;

  /// The hash value used to assign a variation (double from 0 to 1)
  double? bucket;

  /// Used for holdout groups
  bool? passthrough;

  /// If sticky bucketing was used to assign a variation
  bool? stickyBucketUsed;

  factory GBExperimentResult.fromJson(Map<String, dynamic> value) =>
      _$GBExperimentResultFromJson(value);
}
