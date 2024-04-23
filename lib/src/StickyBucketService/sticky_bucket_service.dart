import 'dart:async';
import 'dart:convert';

import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';

abstract class StickyBucketService {
  Future<StickyAssignmentsDocument?> getAssignments(String attributeName, String attributeValue);

  Future<void> saveAssignments(StickyAssignmentsDocument doc);

  Future<Map<StickyAttributeKey, StickyAssignmentsDocument>> getAllAssignments(Map<String, String> attributes);
}

class LocalStorageStickyBucketService extends StickyBucketService {
  final String prefix;
  CachingLayer? localStorage;

  LocalStorageStickyBucketService({this.prefix = 'gbStickyBuckets__', this.localStorage}) {
    localStorage ??= CachingManager();
  }

  @override
  Future<StickyAssignmentsDocument?> getAssignments(String attributeName, String attributeValue) async {
    final key = '$attributeName||$attributeValue';
    StickyAssignmentsDocument? doc;
    try {
      if (localStorage != null) {
        final data = await localStorage!.getContent(fileName: '$prefix$key');
        if (data != null) {
          String jsonString = utf8.decode(data);
          Map<String, dynamic> jsonMap = json.decode(jsonString);

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
        localStorage!.saveContent(fileName: '$prefix$key', content: utf8.encode(json.encode(doc.toJson())));
      }
    } catch (e) {
      // Ignore localStorage errors
    }
  }

  @override
  Future<Map<StickyAttributeKey, StickyAssignmentsDocument>> getAllAssignments(Map<String, String> attributes) async {
    Map<String, StickyAssignmentsDocument> docs = {};
    attributes.forEach((key, value) async {
      var doc = await getAssignments(key, value);
      if (doc != null) {
        String docKey = '${doc.attributeName}||${doc.attributeValue}';
        docs[docKey] = doc;
      }
    });
    return docs;
  }
}
