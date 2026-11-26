import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gives each test file its own temp folder.
///
/// In tests `FileCacheStorage` falls back to `Directory.systemTemp`. Test
/// files run in parallel, so with one shared folder a `clearCache()` in one
/// file can delete a cache file that another file is still writing.
///
/// Each test file runs in its own isolate, so a global override is per file.
/// A zoned override would not work: test bodies do not run in this zone.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final testTempDir = Directory.systemTemp.createTempSync('growthbook_test_');
  IOOverrides.global = _TempDirOverrides(testTempDir);
  tearDownAll(() async {
    try {
      await testTempDir.delete(recursive: true);
    } on FileSystemException {
      // A cache write that outlived the tests may still touch the folder.
    }
  });

  await testMain();
}

final class _TempDirOverrides extends IOOverrides {
  _TempDirOverrides(this._tempDir);

  final Directory _tempDir;

  @override
  Directory getSystemTempDirectory() => _tempDir;
}
