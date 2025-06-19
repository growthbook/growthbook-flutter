import 'package:growthbook_sdk_flutter/src/Utils/converter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tuple/tuple.dart';

part 'wrapper.g.dart';

@Tuple2Converter()
@JsonSerializable()
class Tuple2Wrapper {
  Tuple2<double, double> tuple;

  Tuple2Wrapper(this.tuple);

  factory Tuple2Wrapper.fromJson(Map<String, dynamic> json) => _$Tuple2WrapperFromJson(json);

  Map<String, dynamic> toJson() => _$Tuple2WrapperToJson(this);
}
