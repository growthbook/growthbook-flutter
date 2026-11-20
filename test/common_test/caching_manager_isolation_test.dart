import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Regression tests for cache namespacing:
///
/// - `clearCache()` must only remove entries within THIS instance's
///   `GrowthBook-Cache/<sha256(namespace)>/` namespace, so two SDK instances
///   on different connections never wipe each other's data.
/// - `saveContent`, `getContent`, and `removeContent` must all use the same
///   key/path shape, so a value that was written can also be removed and read
///   back.
/// - An un-namespaced instance keeps the pre-namespacing layout and migrates
///   files written by earlier SDK versions.
///
/// The web (`kIsWeb`) branch and the filesystem branch share the same
/// namespace logic (`GrowthBook-Cache/<sha256(namespace)>/<fileName>`), so
/// exercising the filesystem code path gives us confidence the web scoping
/// behaves the same way.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final testCacheDir =
      Directory.systemTemp.createTempSync('gb_cache_test_').path;

  Uint8List bytes(String value) => Uint8List.fromList(utf8.encode(value));

  group('FileCacheStorage isolation', () {
    late FileCacheStorage a;
    late FileCacheStorage b;

    setUp(() {
      a = FileCacheStorage(
          namespace: 'sdk-instance-a', cacheDirectory: testCacheDir);
      b = FileCacheStorage(
          namespace: 'sdk-instance-b', cacheDirectory: testCacheDir);
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

    test('builder namespaces by host as well as API key', () async {
      const fileName = 'gb-features.txt';
      GBSDKBuilderApp builder(String hostURL) => GBSDKBuilderApp(
            apiKey: 'sdk-same-key',
            hostURL: hostURL,
            growthBookTrackingCallBack: (_) {},
            cacheDirectory: testCacheDir,
          );
      final first = builder('https://first.example.test').cachingManager;
      final second = builder('https://second.example.test').cachingManager;

      await first.saveContent(fileName: fileName, content: bytes('first'));

      expect(await second.getContent(fileName: fileName), isNull);
      await first.clearCache();
    });
  });

  group('FileCacheStorage without namespace', () {
    test('uses the pre-namespacing layout', () async {
      final storage = FileCacheStorage(cacheDirectory: testCacheDir);

      expect(await storage.getTargetFile('gbStickyBuckets__id||1'),
          '$testCacheDir/GrowthBook-Cache/gbStickyBuckets__id||1.txt');
    });

    test('clearCache leaves namespaced instances alone', () async {
      final shared = FileCacheStorage(cacheDirectory: testCacheDir);
      final namespaced = FileCacheStorage(
          namespace: 'sdk-instance-c', cacheDirectory: testCacheDir);
      await shared.saveContent(fileName: 'shared.txt', content: bytes('s'));
      await namespaced.saveContent(fileName: 'own.txt', content: bytes('n'));

      await shared.clearCache();

      expect(await shared.getContent(fileName: 'shared.txt'), isNull);
      expect(await namespaced.getContent(fileName: 'own.txt'), isNotNull);
      await namespaced.clearCache();
    });

    group('legacy migration', () {
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      late Directory appCacheDir;
      late File legacyFile;

      setUp(() {
        appCacheDir = Directory.systemTemp.createTempSync('gb_app_cache_');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationCacheDirectory') {
            return appCacheDir.path;
          }
          return null;
        });
        // A unique name, because the legacy location is the real system temp.
        final name = 'gb-legacy-${DateTime.now().microsecondsSinceEpoch}';
        legacyFile =
            File('${Directory.systemTemp.path}/GrowthBook-Cache/$name.txt')
              ..createSync(recursive: true)
              ..writeAsStringSync('legacy');
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        if (legacyFile.existsSync()) legacyFile.deleteSync();
        appCacheDir.deleteSync(recursive: true);
      });

      String nameOf(File file) =>
          file.uri.pathSegments.last.replaceAll('.txt', '');

      test('moves a file from the legacy location on first read', () async {
        final storage = FileCacheStorage();
        final name = nameOf(legacyFile);

        final content = await storage.getContent(fileName: name);

        expect(utf8.decode(content!), 'legacy');
        expect(legacyFile.existsSync(), isFalse);
        expect(
            File('${appCacheDir.path}/GrowthBook-Cache/$name.txt')
                .readAsStringSync(),
            'legacy');
      });

      test('does not resurrect a migrated file after removeContent', () async {
        final storage = FileCacheStorage();
        final name = nameOf(legacyFile);
        await storage.getContent(fileName: name);

        await storage.removeContent(fileName: name);

        expect(await storage.getContent(fileName: name), isNull);
      });

      test('is skipped for a namespaced instance', () async {
        final storage = FileCacheStorage(namespace: 'sdk-instance-d');

        expect(await storage.getContent(fileName: nameOf(legacyFile)), isNull);
        expect(legacyFile.existsSync(), isTrue);
      });

      test('is skipped with an explicit cache directory', () async {
        final storage = FileCacheStorage(cacheDirectory: appCacheDir.path);

        expect(await storage.getContent(fileName: nameOf(legacyFile)), isNull);
        expect(legacyFile.existsSync(), isTrue);
      });
    });
  });
}
