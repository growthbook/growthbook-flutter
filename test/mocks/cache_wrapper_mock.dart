import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

class MockCacheDirectoryWrapper implements CacheDirectoryWrapper {
  @override
  final CacheDirectoryType directory;

  MockCacheDirectoryWrapper(this.directory);

  @override
  Future<String> get path async => 'mockdir';

  @override
  CacheDirectoryType get cacheDirectoryType => directory;
}
