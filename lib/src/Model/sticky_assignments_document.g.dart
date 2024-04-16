// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sticky_assignments_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StickyAssignmentsDocument _$StickyAssignmentsDocumentFromJson(
        Map<String, dynamic> json) =>
    StickyAssignmentsDocument(
      attributeName: json['attributeName'] as String,
      attributeValue: json['attributeValue'] as String,
      assignments: Map<String, String>.from(json['assignments'] as Map),
    );

Map<String, dynamic> _$StickyAssignmentsDocumentToJson(
        StickyAssignmentsDocument instance) =>
    <String, dynamic>{
      'attributeName': instance.attributeName,
      'attributeValue': instance.attributeValue,
      'assignments': instance.assignments,
    };
