import 'dart:async';
import 'dart:convert';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';

abstract class StickyBucketService {
  Future<StickyAssignmentsDocument?> getAssignments(
      String attributeName, String attributeValue);

  Future<void> saveAssignments(StickyAssignmentsDocument doc);

  Future<Map<StickyAttributeKey, StickyAssignmentsDocument>> getAllAssignments(
      Map<String, String> attributes);
}

class LocalStorageStickyBucketService extends StickyBucketService {
  final String prefix;
  CacheStorage? localStorage;

  final utf8Encoder = const Utf8Encoder();

  LocalStorageStickyBucketService(
      {this.prefix = 'gbStickyBuckets__', this.localStorage}) {
    localStorage ??= FileCacheStorage();
  }

  @override
  Future<StickyAssignmentsDocument?> getAssignments(
      String attributeName, String attributeValue) async {
    final key = '$attributeName||$attributeValue';
    StickyAssignmentsDocument? doc;
    try {
      if (localStorage != null) {
        final data = await localStorage!.getContent(fileName: '$prefix$key');
        if (data != null) {
          // Use generated method directly with proper error handling
          final jsonString = utf8.decode(data);
          final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
          doc = StickyAssignmentsDocument.fromJson(jsonMap);
        }
      }
    } catch (e) {
      // Ignore localStorage errors
    }
    return doc;
  }

  @override
  Future<void> saveAssignments(StickyAssignmentsDocument doc) async {
    final key = '${doc.attributeName}||${doc.attributeValue}';
    try {
      if (localStorage != null) {
        final content = utf8Encoder.convert(jsonEncode(doc.toJson()));
        localStorage!.saveContent(fileName: '$prefix$key', content: content);
      }
    } catch (e) {
      // Ignore localStorage errors
    }
  }

  @override
Future<Map<StickyAttributeKey, StickyAssignmentsDocument>> getAllAssignments(
    Map<String, String> attributes) async {
  final docs = <StickyAttributeKey, StickyAssignmentsDocument>{};

  for (final entry in attributes.entries) {
    final doc = await getAssignments(entry.key, entry.value);
    if (doc != null) {
      final docKey = '${doc.attributeName}||${doc.attributeValue}';
      docs[docKey] = doc;
    }
  }

  return docs;
}

}
