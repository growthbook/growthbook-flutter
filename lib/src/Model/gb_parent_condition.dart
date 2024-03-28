import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'gb_parent_condition.g.dart';


@JsonSerializable(createToJson: false)
class GBParentCondition {
  String id;
  GBCondition condition;
  bool? gate;

  GBParentCondition({required this.id, required this.condition, this.gate});


  factory GBParentCondition.fromJson(Map<String, dynamic> value) =>
      _$GBParentConditionFromJson(value);
}