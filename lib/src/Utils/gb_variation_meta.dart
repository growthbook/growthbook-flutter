import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
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

  @override
  String toString() {
    return "key: $key \n"
        "name: $name \n"
        "passthrough: $passthrough \n";
  }
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

  @override
  String toString() {
    return "experiment: $experiment \n"
        "featureResult: $featureResult \n";
  }
}
