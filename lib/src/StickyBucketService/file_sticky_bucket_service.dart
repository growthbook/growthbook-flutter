import 'dart:convert';
import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';

class FileStickyBucketService extends StickyBucketService {
  final String prefix;
  CachingLayer? localStorage;

  final utf8Encoder = const Utf8Encoder();

  FileStickyBucketService({
    this.prefix = 'gbStickyBuckets__',
    this.localStorage,
  }) {
    localStorage ??= CachingManager();
  }

  @override
  Future<StickyAssignmentsDocument?> getAssignments({
    required String attributeName,
    required String attributeValue,
  }) async {
    final key = '$attributeName||$attributeValue';
    StickyAssignmentsDocument? doc;

    try {
      if (localStorage != null) {
        final data = await localStorage!.getContent(fileName: '$prefix$key');
        if (data != null) {
          final jsonString = utf8.decode(data);
          final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
          doc = StickyAssignmentsDocument.fromJson(jsonMap);
        }
      }
    } catch (e) {
      log('Failed to get assignments: $e');
    }
    return doc;
  }

  @override
  Future<void> saveAssignments({required StickyAssignmentsDocument doc}) async {
    final key = '${doc.attributeName}||${doc.attributeValue}';
    try {
      if (localStorage != null) {
        final content = utf8Encoder.convert(jsonEncode(doc.toJson()));
        await localStorage!.saveContent(fileName: '$prefix$key', content: content);
      }
    } catch (e) {
      log('Failed to save assignments $e');
    }
  }

  @override
  Future<Map<String, StickyAssignmentsDocument>> getAllAssignments({
    required Map<String, String> attributes,
    AllAssignmentsCallback? allAssignmentsCallback,
  }) async {
    final docs = <String, StickyAssignmentsDocument>{};

    try {
      for (final entry in attributes.entries) {
        final doc = await getAssignments(attributeName: entry.key, attributeValue: entry.value);
        if (doc != null) {
          final docKey = '${doc.attributeName}||${doc.attributeValue}';
          docs[docKey] = doc;
        }
      }
    } catch (e) {
      log('Failed to get all assignments: $e');
    }
    allAssignmentsCallback?.call(docs.isNotEmpty ? docs : null);
    return docs;
  }
}
