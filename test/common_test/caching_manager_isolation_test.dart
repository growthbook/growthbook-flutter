import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Regression tests for the cache namespace fixes in PR #157:
///
/// - `clearCache()` must only remove entries within THIS instance's
///   `GrowthBook-Cache/<sha256(apiKey)>/` namespace, so two SDK instances with
///   different API keys never wipe each other's data.
/// - `saveContent`, `getContent`, and `removeContent` must all use the same
///   key/path shape, so a value that was written can also be removed and read
///   back.
/// - Truncating the hash to 5 hex chars (20 bits) previously risked collisions
///   between distinct API keys; the full digest keeps namespaces disjoint.
///
/// The web (`kIsWeb`) branch and the filesystem branch share the same
/// namespace logic (`GrowthBook-Cache/<sha256(apiKey)>/<fileName>`), so
/// exercising the filesystem code path gives us confidence the web scoping
/// behaves the same way.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileCacheStorage isolation', () {
    late FileCacheStorage a;
    late FileCacheStorage b;

    setUp(() {
      a = FileCacheStorage(apiKey: 'sdk-instance-a');
      b = FileCacheStorage(apiKey: 'sdk-instance-b');
    });

    tearDown(() async {
      await a.clearCache();
      await b.clearCache();
    });

    test('clearCache on one instance does not affect the other', () async {
      const fileName = 'features.txt';
      await a.saveContent(
        fileName: fileName,
        content: Uint8List.fromList(utf8.encode('{"from":"a"}')),
      );
      await b.saveContent(
        fileName: fileName,
        content: Uint8List.fromList(utf8.encode('{"from":"b"}')),
      );

      await a.clearCache();

      expect(await a.getContent(fileName: fileName), isNull,
          reason: "a's cache was cleared, so its content should be gone");
      final fromB = await b.getContent(fileName: fileName);
      expect(fromB, isNotNull, reason: "b's cache must survive a.clearCache()");
      expect(utf8.decode(fromB!), '{"from":"b"}');
    });

    test('save + get + remove round-trip uses a consistent key shape',
        () async {
      const fileName = 'roundtrip.txt';
      final payload = Uint8List.fromList(utf8.encode('hello'));

      await a.saveContent(fileName: fileName, content: payload);
      expect(await a.getContent(fileName: fileName), isNotNull);

      await a.removeContent(fileName: fileName);
      expect(await a.getContent(fileName: fileName), isNull,
          reason: 'removeContent must target the same location as saveContent, '
              'otherwise corrupted entries cannot be evicted');
    });

    test('different apiKeys produce isolated storage', () async {
      const fileName = 'shared-name.txt';
      await a.saveContent(
        fileName: fileName,
        content: Uint8List.fromList(utf8.encode('a-payload')),
      );
      await b.saveContent(
        fileName: fileName,
        content: Uint8List.fromList(utf8.encode('b-payload')),
      );

      final fromA = await a.getContent(fileName: fileName);
      final fromB = await b.getContent(fileName: fileName);

      expect(fromA, isNotNull);
      expect(fromB, isNotNull);
      expect(utf8.decode(fromA!), 'a-payload');
      expect(utf8.decode(fromB!), 'b-payload');
    });
  });
}
