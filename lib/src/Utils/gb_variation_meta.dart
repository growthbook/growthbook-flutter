import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/experiment.dart';
import 'package:growthbook_sdk_flutter/src/Model/experiment_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'gb_variation_meta.g.dart';

/// Meta info about the variations
@JsonSerializable()
class GBVariationMeta {
  GBVariationMeta({
    this.key,
    this.name,
    this.passthrough,
  });

  final String? key;

  final String? name;

  final bool? passthrough;

  factory GBVariationMeta.fromJson(Map<String, dynamic> value) => _$GBVariationMetaFromJson(value);

  Map<String, dynamic> toJson() => _$GBVariationMetaToJson(this);
}

/// Used for remote feature evaluation to trigger the `TrackingCallback`
@JsonSerializable()
class GBTrack {
  GBTrack({
    this.experiment,
    this.featureResult,
  });

  final GBExperiment? experiment;

  final GBFeatureResult? featureResult;

  factory GBTrack.fromJson(Map<String, dynamic> value) => _$GBTrackFromJson(value);

  Map<String, dynamic> toJson() => _$GBTrackToJson(this);
}

/// Used for remote feature evaluation to trigger the `TrackingCallback`
@JsonSerializable()
class GBTrackData {
  GBTrackData({
    required this.experiment,
    required this.experimentResult,
  });

  final GBExperiment experiment;

  final GBExperimentResult experimentResult;

  factory GBTrackData.fromJson(Map<String, dynamic> value) => _$GBTrackDataFromJson(value);

  Map<String, dynamic> toJson() => _$GBTrackDataToJson(this);
}

@JsonSerializable()
class AssignedExperiment {
  AssignedExperiment({
    required this.experiment,
    required this.experimentResult,
  });

  final GBExperiment experiment;
  final GBExperimentResult experimentResult;
}
