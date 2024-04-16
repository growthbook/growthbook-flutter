import 'dart:async';
import 'dart:convert';

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
  String prefix;
  CachingManager? localStorage;

  LocalStorageStickyBucketService(
      {this.prefix = 'gbStickyBuckets__', this.localStorage});   

  @override
  Future<StickyAssignmentsDocument?> getAssignments(
      String attributeName, String attributeValue) async {
    final key = '$attributeName||$attributeValue';
    StickyAssignmentsDocument? doc;
    try {
      if (localStorage != null) {
        final data = localStorage!.getContent('$prefix$key');
        if(data != null){
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
        localStorage!.saveContent('$prefix$key', json.encode(doc.toJson()));
      }
    } catch (e) {
      // Ignore localStorage errors
    }
  }

    @override
      Future<Map<StickyAttributeKey, StickyAssignmentsDocument>> getAllAssignments(
      Map<String, String> attributes) async {
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
