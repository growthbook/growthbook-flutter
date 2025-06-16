import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sticky_assignments_document.g.dart';

@JsonSerializable()
class StickyAssignmentsDocument extends Equatable {
  const StickyAssignmentsDocument({
    required this.assignments,
    required this.attributeName,
    required this.attributeValue,
  });

  final Map<String, String> assignments;
  final String attributeName;
  final String attributeValue;

  factory StickyAssignmentsDocument.fromJson(Map<String, dynamic> value) =>
      _$StickyAssignmentsDocumentFromJson(value);

  Map<String, dynamic> toJson() => _$StickyAssignmentsDocumentToJson(this);

  @override
  List<Object?> get props => [assignments];
}

typedef StickyAssignments = Map<StickyExperimentKey, String>;

typedef StickyExperimentKey = String; // `${experimentId}__{version}`

typedef StickyAttributeKey = String; // `${attributeName}||${attributeValue}`
