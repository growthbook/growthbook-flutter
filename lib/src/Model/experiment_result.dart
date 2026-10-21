import 'package:json_annotation/json_annotation.dart';

part 'experiment_result.g.dart';

String? _toStringValue(dynamic value) => value?.toString();
String _toStringRequired(dynamic value) => value.toString();

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
    this.leafId,
    this.variationWeights,
    this.banditVersion,
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
  @JsonKey(fromJson: _toStringValue)
  String? hashValue;

  /// Whether or not the user is part of the experiment
  bool inExperiment;

  //new properties v0.4.0
  /// The unique key for the assigned variation
  @JsonKey(fromJson: _toStringRequired)
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

  /// When the assignment came from a contextual-bandit rule, the id of the
  /// matched leaf (`-1` if no leaf matched and fallback weights were used).
  /// `null` otherwise.
  int? leafId;

  /// When the assignment came from a contextual-bandit rule, the weights that
  /// were applied. `null` otherwise.
  List<double>? variationWeights;

  /// When the assignment came from a contextual-bandit rule, the version of
  /// the backend-computed weights that produced this assignment. `null`
  /// otherwise.
  int? banditVersion;

  factory GBExperimentResult.fromJson(Map<String, dynamic> value) =>
      _$GBExperimentResultFromJson(value);

  Map<String, dynamic> toJson() => _$GBExperimentResultToJson(this);
}
