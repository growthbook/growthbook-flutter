import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

/// Gives every suite a cache directory of its own.
///
/// `flutter test` runs suites in parallel, and `CachingManager` wrote all of
/// them into a single `<systemTemp>/GrowthBook-Cache`. `clearCache()` deletes
/// that folder recursively, so a suite tearing down removed the directory
/// another was writing into — the second one then failed on a missing file or
/// on a `PathNotFoundException` from the rename, depending on the timing. It
/// is a race, so it surfaced as an unrelated test going red at random.
///
/// `flutter test` applies this file to every suite under `test/`, which is why
/// the isolation lives here rather than in a helper each suite has to
/// remember to call: a new suite that reaches `CachingManager` would otherwise
/// silently go back to sharing the folder. Static state is per-isolate and
/// each suite is its own isolate, so the override cannot leak across files.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Nullable rather than `late`: if createTempSync throws, tearDownAll must
  // report that failure instead of a LateInitializationError on top of it.
  Directory? directory;

  setUpAll(() {
    directory = Directory.systemTemp.createTempSync('gb-cache-test-');
    CachingManager().cacheDirectoryOverride = directory!.path;
  });

  tearDownAll(() async {
    // Waits for any write still in flight before the directory goes.
    await CachingManager().clearCache();
    CachingManager().cacheDirectoryOverride = null;
    if (directory?.existsSync() ?? false) {
      directory!.deleteSync(recursive: true);
    }
  });

  // Registered as callbacks, not run around `testMain()`: that call only
  // declares the tests, so cleanup placed after it would delete the directory
  // before a single test had run.
  await testMain();
}
