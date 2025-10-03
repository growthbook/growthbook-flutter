import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';

class InMemoryStickyBucketService extends StickyBucketService {
  final Map<String, StickyAssignmentsDocument> _inMemoryCache = {};
  final String prefix;

  InMemoryStickyBucketService({this.prefix = 'gbStickyBuckets__'});

  @override
  Future<StickyAssignmentsDocument?> getAssignments({
    required String attributeName,
    required String attributeValue,
  }) async {
    final key = '$prefix$attributeName||$attributeValue';
    return _inMemoryCache[key];
  }

  @override
  Future<void> saveAssignments({required StickyAssignmentsDocument doc}) async {
    final key = '$prefix${doc.attributeName}||${doc.attributeValue}';
    _inMemoryCache[key] = doc;
  }

  @override
  Future<Map<String, StickyAssignmentsDocument>> getAllAssignments({
    required Map<String, String> attributes,
    AllAssignmentsCallback? allAssignmentsCallback,
  }) async {
    final docs = <String, StickyAssignmentsDocument>{};

    for (final entry in attributes.entries) {
      final key = '$prefix${entry.key}||${entry.value}';
      final doc = _inMemoryCache[key];
      if (doc != null) {
        docs[key] = doc;
      }
    }

    allAssignmentsCallback?.call(docs.isNotEmpty ? docs : null);
    return docs;
  }
}
