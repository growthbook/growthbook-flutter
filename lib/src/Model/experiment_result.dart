import 'package:json_annotation/json_annotation.dart';

part 'experiment_result.g.dart';

/// The result of running an Experiment given a specific Context
@JsonSerializable()
class GBExperimentResult {
  GBExperimentResult({
    this.bucket,
    this.featureId,
    this.hashAttribute,
    this.hashUsed,
    this.hashValue,
    required this.inExperiment,
    required this.key,
    this.stickyBucketUsed,
    this.value,
    this.variationID,
    this.name,
    this.passthrough,
  });

  /// The hash value used to assign a variation (double from 0 to 1)
  double? bucket;

  /// The id of the feature (if any) that the experiment came from
  String? featureId;

  /// The user attribute used to assign a variation
  String? hashAttribute;

  /// If a hash was used to assign a variation
  bool? hashUsed;

  /// The value of that attribute
  String? hashValue;

  /// Whether or not the user is part of the experiment
  bool inExperiment;

  //new properties v0.4.0
  /// The unique key for the assigned variation
  String key;

  /// If sticky bucketing was used to assign a variation
  bool? stickyBucketUsed;

  /// The array value of the assigned variation
  dynamic value;

  /// The array index of the assigned variation
  int? variationID;

  /// The human-readable name of the assigned variation
  String? name;

  /// Used for holdout groups
  bool? passthrough;

  factory GBExperimentResult.fromJson(Map<String, dynamic> value) =>
      _$GBExperimentResultFromJson(value);

  Map<String, dynamic> toJson() => _$GBExperimentResultToJson(this);

}
