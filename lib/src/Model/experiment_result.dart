import 'package:json_annotation/json_annotation.dart';

part 'experiment_result.g.dart';

/// The result of running an Experiment given a specific Context
@JsonSerializable()
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

  Map<String, dynamic> toJson() => _$GBExperimentResultToJson(this);

}
