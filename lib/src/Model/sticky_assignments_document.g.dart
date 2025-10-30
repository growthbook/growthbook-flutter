// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sticky_assignments_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StickyAssignmentsDocument _$StickyAssignmentsDocumentFromJson(
        Map<String, dynamic> json) =>
    StickyAssignmentsDocument(
      assignments: Map<String, String>.from(json['assignments'] as Map),
      attributeName: json['attributeName'] as String,
      attributeValue: json['attributeValue'] as String,
    );

Map<String, dynamic> _$StickyAssignmentsDocumentToJson(
        StickyAssignmentsDocument instance) =>
    <String, dynamic>{
      'assignments': instance.assignments,
      'attributeName': instance.attributeName,
      'attributeValue': instance.attributeValue,
    };
