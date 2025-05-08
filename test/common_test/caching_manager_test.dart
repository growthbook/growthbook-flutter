import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/cache_wrapper_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Caching manager test', () {
    final manager = CachingManager();
    manager.setSystemCacheDirectory(
        MockCacheDirectoryWrapper(CacheDirectoryType.applicationSupport));
    test('Caching file name', () async {
      const String fileName = "gb-features.txt";
      final String filePath = await manager.getTargetFile(fileName);

      expect(filePath.endsWith(fileName), isTrue);
    });

    test('Caching test', () async {
      const fileName = "gb-features.txt";
      try {
        final data = {'GrowthBook': 'GrowthBook'};
        final jsonData = json.encode(data).codeUnits;
        final Uint8List jsonDataUint8 = Uint8List.fromList(jsonData);
        await manager.saveContent(fileName: fileName, content: jsonDataUint8);

        final fileContentsUint8 = await manager.getContent(fileName: fileName);
        if (fileContentsUint8 != null) {
          final fileContents = fileContentsUint8.toList();
          final decodedJson = json.decode(utf8.decode(fileContents));
          expect(decodedJson, equals(data));
        } else {
          fail('Failed to get content');
        }
      } catch (error) {
        fail('Failed to get raw data or parse JSON error: $error');
      }
    });

    test('Clear cache test', () async {
      const String fileName = "gb-features.txt";

      try {
        final data = {'GrowthBook': 'GrowthBook'};
        final jsonData = json.encode(data).codeUnits;
        final Uint8List jsonDataUint8 = Uint8List.fromList(jsonData);
        await manager.saveContent(fileName: fileName, content: jsonDataUint8);

        await manager.clearCache();

        final content = await manager.getContent(fileName: fileName);

        expect(content, isNull);
      } catch (error) {
        fail('Failed to get raw data or parse JSON error: $error');
      }
    });
  });

  tearDownAll(() async {
    final dir = Directory(
        await MockCacheDirectoryWrapper(CacheDirectoryType.applicationSupport)
            .path);
    await dir.delete(recursive: true);
  });
}
