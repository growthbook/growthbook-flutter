import 'dart:async';
import 'dart:convert';

import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';

abstract class StickyBucketService {
  Future<StickyAssignmentsDocument?> getAssignments(
      String attributeName, String attributeValue);

  Future<void> saveAssignments(StickyAssignmentsDocument doc);

  Future<Map<StickyAttributeKey, StickyAssignmentsDocument>> getAllAssignments(
      Map<String, String> attributes) async {
    var docs = <String, StickyAssignmentsDocument>{};
    await Future.wait(attributes.entries.map((entry) async {
      var doc = await getAssignments(entry.key, entry.value);
      if (doc != null) {
        var key = '${doc.attributeName}||${doc.attributeValue}';
        docs[key] = doc;
      }
    }));
    return docs;
  }
}

abstract class LocalStorageCompat {
  Future<String?> getItem(String key);
  Future<void> setItem(String key, String value);
}

class LocalStorageStickyBucketService extends StickyBucketService {
  String prefix;
  LocalStorageCompat? localStorage;

  LocalStorageStickyBucketService(
      {this.prefix = 'gbStickyBuckets__', this.localStorage});

  @override
  Future<StickyAssignmentsDocument?> getAssignments(
      String attributeName, String attributeValue) async {
    final key = '$attributeName||$attributeValue';
    StickyAssignmentsDocument? doc;
    try {
      if (localStorage != null) {
        final raw = await localStorage!.getItem(prefix + key) ?? '{}';
        final data = json.decode(raw);
        if (data['attributeName'] != null &&
            data['attributeValue'] != null &&
            data['assignments'] != null) {
          doc = StickyAssignmentsDocument.fromJson(data);
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
        await localStorage!.setItem(prefix + key, json.encode(doc.toJson()));
      }
    } catch (e) {
      // Ignore localStorage errors
    }
  }
}
