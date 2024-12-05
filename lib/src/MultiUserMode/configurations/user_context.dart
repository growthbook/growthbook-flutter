import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';

class UserContext {
  UserContext({
    this.attributes,
    this.url,
    this.stickyBucketAssignmentDocs,
    this.forcedVariationsMap = const <String, int>{},
    this.forcedFeatureValues,
    this.attributesJson,
  });

  Map<String, dynamic>? attributes;

  String? url;

  Map<String, StickyAssignmentsDocument>? stickyBucketAssignmentDocs;

  Map<String, dynamic>? forcedVariationsMap;

  Map<String, dynamic>? forcedFeatureValues;

  String? attributesJson;
}
