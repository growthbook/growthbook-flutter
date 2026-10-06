import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

/// Gives the calling suite a cache directory of its own.
///
/// `flutter test` runs suites in parallel, and `CachingManager` wrote every one
/// of them into a single `<systemTemp>/GrowthBook-Cache`. `clearCache()` deletes
/// that folder recursively, so a suite tearing down removed the directory
/// another was writing into — the second one then failed on a missing file or a
/// `PathNotFoundException` from the rename, depending on the timing.
///
/// Call once at the top of `main()`. Static state is per-isolate and each suite
/// is its own isolate, so the override cannot leak across files.
void useIsolatedCache() {
  late Directory directory;

  setUpAll(() {
    directory = Directory.systemTemp.createTempSync('gb-cache-test-');
    CachingManager().cacheDirectoryOverride = directory.path;
  });

  tearDownAll(() {
    CachingManager().cacheDirectoryOverride = null;
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
}
