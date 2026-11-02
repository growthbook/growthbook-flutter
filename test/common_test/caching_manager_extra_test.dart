import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

void main() {
  group('CachingManager — additional coverage', () {
    final manager = CachingManager();

    tearDown(() async {
      await manager.clearCache();
    });

    // -------------------------------------------------------------------------
    // getData — alias for getContent
    // -------------------------------------------------------------------------
    group('getData', () {
      test('returns null when file does not exist', () async {
        final result = await manager.getData(fileName: 'nonexistent-file');
        expect(result, isNull);
      });

      test('returns content that was previously saved', () async {
        const fileName = 'test-get-data';
        final content = Uint8List.fromList(utf8.encode('{"test":1}'));
        await manager.saveContent(fileName: fileName, content: content);

        final result = await manager.getData(fileName: fileName);
        expect(result, isNotNull);
        expect(utf8.decode(result!), '{"test":1}');
      });
    });

    // -------------------------------------------------------------------------
    // removeContent
    // -------------------------------------------------------------------------
    group('removeContent', () {
      test('removes an existing file so getContent returns null', () async {
        const fileName = 'test-remove-existing';
        final content = Uint8List.fromList(utf8.encode('data'));
        await manager.saveContent(fileName: fileName, content: content);

        // Confirm it exists first
        expect(await manager.getContent(fileName: fileName), isNotNull);

        await manager.removeContent(fileName: fileName);

        expect(await manager.getContent(fileName: fileName), isNull);
      });

      test('does not throw when removing a nonexistent file', () async {
        await expectLater(
          manager.removeContent(fileName: 'does-not-exist'),
          completes,
        );
      });
    });

    // -------------------------------------------------------------------------
    // clearCache — already-empty directory path
    // -------------------------------------------------------------------------
    group('clearCache', () {
      test('does not throw when cache is already empty', () async {
        await manager.clearCache(); // ensure empty
        await expectLater(manager.clearCache(), completes);
      });
    });
  });
}
