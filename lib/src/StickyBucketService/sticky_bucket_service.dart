import 'dart:async';

import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';

typedef AllAssignmentsCallback = void Function(Map<String, StickyAssignmentsDocument>?);

abstract class StickyBucketService {
  Future<StickyAssignmentsDocument?> getAssignments({
    required String attributeName,
    required String attributeValue,
  });

  Future<void> saveAssignments({required StickyAssignmentsDocument doc});

  Future<Map<String, StickyAssignmentsDocument>> getAllAssignments({
    required Map<String, String> attributes,
    AllAssignmentsCallback? allAssignmentsCallback,
  });
}
