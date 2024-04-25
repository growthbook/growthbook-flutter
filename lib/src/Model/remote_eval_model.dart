import 'package:json_annotation/json_annotation.dart';

part 'remote_eval_model.g.dart';

/// A Feature object consists of possible values plus rules for how to assign values to users.
@JsonSerializable()
class RemoteEvalModel {
  RemoteEvalModel({
    this.attributes,
    this.forcedFeatures,
    this.forcedVariations,
  });

  final Map<String, dynamic>? attributes;
  final List<dynamic>? forcedFeatures;
  final Map<String, dynamic>? forcedVariations;

  factory RemoteEvalModel.fromJson(Map<String, dynamic> json) => _$RemoteEvalModelFromJson(json);

  Map<String, dynamic> toJson() => _$RemoteEvalModelToJson(this);
}
