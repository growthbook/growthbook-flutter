import 'package:json_annotation/json_annotation.dart';
import 'package:tuple/tuple.dart';

class Tuple2Converter
    implements JsonConverter<Tuple2<double, double>, Map<String, dynamic>> {
  const Tuple2Converter();

  @override
  Tuple2<double, double> fromJson(Map<String, dynamic> json) {
    final first = json['item1'] as double;
    final second = json['item2'] as double;
    return Tuple2<double, double>(first, second);
  }

  @override
  Map<String, dynamic> toJson(Tuple2<double, double> tuple) =>
      {'item1': tuple.item1, 'item2': tuple.item2};
}
