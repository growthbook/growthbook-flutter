import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/gb_parent_condition.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_filter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_variation_meta.dart';
import 'package:json_annotation/json_annotation.dart';

part 'features.g.dart';

/// A Feature object consists of possible values plus rules for how to assign values to users.
@JsonSerializable()
class GBFeature {
  GBFeature({
    this.rules,
    this.defaultValue,
  });

  /// The default value (should use null if not specified)
  ///2 Array of Rule objects that determine when and how the defaultValue gets overridden
  List<GBFeatureRule>? rules;

  ///  The default value (should use null if not specified)
  dynamic defaultValue;

  factory GBFeature.fromJson(Map<String, dynamic> value) => _$GBFeatureFromJson(value);

  Map<String, dynamic> toJson() => _$GBFeatureToJson(this);
}

/// Rule object consists of various definitions to apply to calculate feature value
@JsonSerializable()
class GBFeatureRule {
  GBFeatureRule({
    this.id,
    this.condition,
    this.coverage,
    this.force,
    this.variations,
    this.key,
    this.weights,
    this.namespace,
    this.hashAttribute,
    this.fallbackAttribute,
    this.hashVersion,
    this.disableStickyBucketing,
    this.bucketVersion,
    this.minBucketVersion,
    this.range,
    this.ranges,
    this.meta,
    this.filters,
    this.seed,
    this.name,
    this.phase,
    this.tracks,
    this.parentConditions,
  });

  /// Unique feature rule id
  String? id;

  /// Optional targeting condition
  GBCondition? condition;

  // Each item defines a prerequisite where a condition must evaluate against a parent feature's
  // value (identified by id). If gate is true, then this is a blocking feature-level prerequisite;
  // otherwise it applies to the current rule only.
  List<GBParentCondition>? parentConditions;

  /// What percent of users should be included in the experiment (between 0 and 1, inclusive)
  double? coverage;

  /// Immediately force a specific value (ignore every other option besides condition and coverage)
  dynamic force;

  /// Run an experiment (A/B test) and randomly choose between these variations
  List<dynamic>? variations;

  /// The globally unique tracking key for the experiment (default to the feature key)
  String? key;

  /// How to weight traffic between variations. Must add to 1.
  List<double>? weights;

  /// A tuple that contains the namespace identifier, plus a range of coverage for the experiment.
  List? namespace;

  /// What user attribute should be used to assign variations (defaults to id)
  String? hashAttribute;

  /// When using sticky bucketing, can be used as a fallback to assign variations
  String? fallbackAttribute;

  // new properties v0.4.0
  /// The hash version to use
  int? hashVersion;

  /// If true, sticky bucketing will be disabled for this experiment. (Note: sticky bucketing is only available if a StickyBucketingService is provided in the Context)
  bool? disableStickyBucketing;

  /// An sticky bucket version number that can be used to force a re-bucketing of users (default to '0')
  int? bucketVersion;

  /// Any users with a sticky bucket version less than this will be excluded from the experiment
  int? minBucketVersion;

  /// A more precise version of coverage
  GBBucketRange? range;

  /// Ranges for experiment variations
  List<GBBucketRange>? ranges;

  /// Meta info about the experiment variations
  List<GBVariationMeta>? meta;

  /// Array of filters to apply to the rule
  List<GBFilter>? filters;

  /// Seed to use for hashing
  String? seed;

  /// Human-readable name for the experiment
  String? name;

  /// The phase id of the experiment
  String? phase;

  /// Array of tracking calls to fire
  // GBTrack? tracks;
  List<GBTrack>? tracks;

  factory GBFeatureRule.fromJson(Map<String, dynamic> value) => _$GBFeatureRuleFromJson(value);

  Map<String, dynamic> toJson() => _$GBFeatureRuleToJson(this);
}

/// Enum For defining feature value source.

enum GBFeatureSource {
  /// Queried Feature doesn't exist in GrowthBook.
  unknownFeature("unknownFeature"),

  /// Default Value for the Feature is being processed.
  defaultValue("defaultValue"),

  /// Forced Value for the Feature is being processed.
  force("force"),

  /// Experiment Value for the Feature is being processed.
  experiment("experiment"),

  // CyclicPrerequisite Value for the Feature is being processed
  cyclicPrerequisite("cyclicPrerequisite"),

  // Prerequisite Value for the Feature is being processed
  prerequisite("prerequisite");

  const GBFeatureSource(this.name);
  final String name;
}

/// Result for Feature
@JsonSerializable()
class GBFeatureResult {
  GBFeatureResult({
    this.value,
    this.on = false,
    this.off = true,
    this.source,
    this.experiment,
    this.experimentResult,
  });

  /// The assigned value of the feature
  dynamic value;

  /// The assigned value cast to a boolean
  bool on;

  /// The assigned value cast to a boolean and then negated
  bool off;

  /// One of "unknownFeature", "defaultValue", "force", or "experiment"

  GBFeatureSource? source;

  /// When source is "experiment", this will be the Experiment object used
  GBExperiment? experiment;

  ///When source is "experiment", this will be an ExperimentResult object
  GBExperimentResult? experimentResult;

  factory GBFeatureResult.fromJson(Map<String, dynamic> value) => _$GBFeatureResultFromJson(value);

  Map<String, dynamic> toJson() => _$GBFeatureResultToJson(this);
}
