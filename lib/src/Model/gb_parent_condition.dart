import 'package:json_annotation/json_annotation.dart';

part 'gb_parent_condition.g.dart';


@JsonSerializable()
class GBParentCondition {
  final String id;
  final Map<String, dynamic> condition;
  final bool? gate;

  GBParentCondition({required this.id, required this.condition, this.gate});


  factory GBParentCondition.fromJson(Map<String, dynamic> value) =>
      _$GBParentConditionFromJson(value);

   Map<String, dynamic> toJson() => _$GBParentConditionToJson(this);     
}