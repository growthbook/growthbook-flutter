import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';

// In-memory CachingLayer to avoid touching the real filesystem between tests.
class _InMemoryCache implements CacheStorage {
  final _store = <String, Uint8List>{};

  @override
  Future<Uint8List?> getContent({required String fileName}) async =>
      _store[fileName];

  @override
  Future<void> saveContent({
    required String fileName,
    required Uint8List content,
  }) async =>
      _store[fileName] = content;

  @override
  Future<void> removeContent({required String fileName}) async =>
      _store.remove(fileName);

  @override
  Future<void> clearCache() async => _store.clear();
}

// CacheStorage that always throws on both read and write.
class _ThrowingCache implements CacheStorage {
  @override
  Future<Uint8List?> getContent({required String fileName}) =>
      throw Exception('storage unavailable');

  @override
  Future<void> saveContent({
    required String fileName,
    required Uint8List content,
  }) =>
      throw Exception('storage unavailable');

  @override
  Future<void> removeContent({required String fileName}) async {}

  @override
  Future<void> clearCache() async {}
}

LocalStorageStickyBucketService _makeService({CacheStorage? cache}) =>
    LocalStorageStickyBucketService(
      localStorage: cache ?? _InMemoryCache(),
    );

StickyAssignmentsDocument _doc({
  String name = 'id',
  String value = 'user-1',
  Map<String, String>? assignments,
}) =>
    StickyAssignmentsDocument(
      attributeName: name,
      attributeValue: value,
      assignments: assignments ?? {'exp__0': '0'},
    );

void main() {
  group('LocalStorageStickyBucketService', () {
    // -------------------------------------------------------------------------
    // getAssignments
    // -------------------------------------------------------------------------
    group('getAssignments', () {
      test('returns null when nothing is stored', () async {
        final svc = _makeService();
        final result = await svc.getAssignments('id', 'user-1');
        expect(result, isNull);
      });

      test('returns the stored document after saveAssignments', () async {
        final svc = _makeService();
        final doc = _doc();
        await svc.saveAssignments(doc);
        final result = await svc.getAssignments('id', 'user-1');
        expect(result, isNotNull);
        expect(result!.attributeName, 'id');
        expect(result.attributeValue, 'user-1');
        expect(result.assignments['exp__0'], '0');
      });

      test('returns null and does not throw when cache throws', () async {
        final svc = _makeService(cache: _ThrowingCache());
        final result = await svc.getAssignments('id', 'user-1');
        expect(result, isNull);
      });

      test('returns null when stored bytes are corrupt JSON', () async {
        final cache = _InMemoryCache();
        const prefix = 'gbStickyBuckets__';
        cache._store['${prefix}id||user-1'] =
            Uint8List.fromList(utf8.encode('not-valid-json'));

        final svc = LocalStorageStickyBucketService(localStorage: cache);
        final result = await svc.getAssignments('id', 'user-1');
        expect(result, isNull);
      });

      test('returns null when localStorage is null', () async {
        final svc = _makeService();
        svc.localStorage = null;
        final result = await svc.getAssignments('id', 'user-1');
        expect(result, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // saveAssignments
    // -------------------------------------------------------------------------
    group('saveAssignments', () {
      test('does not throw when localStorage is null', () async {
        final svc = _makeService();
        svc.localStorage = null;
        await expectLater(svc.saveAssignments(_doc()), completes);
      });

      test('does not throw when cache throws', () async {
        final svc = _makeService(cache: _ThrowingCache());
        await expectLater(svc.saveAssignments(_doc()), completes);
      });

      test('stores data under prefix + attributeName||attributeValue key', () async {
        final cache = _InMemoryCache();
        const prefix = 'gbStickyBuckets__';
        final svc = LocalStorageStickyBucketService(localStorage: cache);

        await svc.saveAssignments(_doc(name: 'device', value: 'abc'));

        expect(cache._store.containsKey('${prefix}device||abc'), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // getAllAssignments
    // -------------------------------------------------------------------------
    group('getAllAssignments', () {
      test('returns empty map for empty attributes', () async {
        final svc = _makeService();
        final result = await svc.getAllAssignments({});
        expect(result, isEmpty);
      });

      test('returns empty map when no assignments are saved', () async {
        final svc = _makeService();
        final result = await svc.getAllAssignments({'id': 'user-1'});
        expect(result, isEmpty);
      });

      test('returns one entry when one attribute has a saved document', () async {
        final svc = _makeService();
        await svc.saveAssignments(_doc(name: 'id', value: 'user-1'));

        final result = await svc.getAllAssignments({'id': 'user-1'});

        expect(result.length, 1);
        expect(result.containsKey('id||user-1'), isTrue);
        expect(result['id||user-1']!.attributeValue, 'user-1');
      });

      test('returns multiple entries when multiple attributes have saved docs', () async {
        final svc = _makeService();
        await svc.saveAssignments(_doc(name: 'id', value: 'user-1'));
        await svc.saveAssignments(_doc(name: 'device', value: 'device-42'));

        final result = await svc.getAllAssignments({
          'id': 'user-1',
          'device': 'device-42',
        });

        expect(result.length, 2);
        expect(result.containsKey('id||user-1'), isTrue);
        expect(result.containsKey('device||device-42'), isTrue);
      });

      test('skips attributes that have no saved document', () async {
        final svc = _makeService();
        await svc.saveAssignments(_doc(name: 'id', value: 'user-1'));

        final result = await svc.getAllAssignments({
          'id': 'user-1',
          'device': 'unknown',
        });

        expect(result.length, 1);
        expect(result.containsKey('id||user-1'), isTrue);
        expect(result.containsKey('device||unknown'), isFalse);
      });
    });
  });
}
