import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';


enum CacheDirectoryType {
  applicationSupport,
  caches,
  documents,
  library,
  customPath
}

abstract class CacheDirectoryWrapper {
  CacheDirectoryType get cacheDirectoryType;
  Future<String> get path;
}

class DefaultCacheDirectoryWrapper implements CacheDirectoryWrapper {
  @override
  CacheDirectoryType cacheDirectory;

  String? customCachePath;

  DefaultCacheDirectoryWrapper(
    this.cacheDirectory, {
    String? customCachePath,
  }) {
    if (cacheDirectory == CacheDirectoryType.customPath &&
        customCachePath != null) {
      this.customCachePath = customCachePath;
    }
  }

  @override
  Future<String> get path async {
    if (kIsWeb) {
      return "";
    }
    switch (cacheDirectory) {
      case CacheDirectoryType.applicationSupport:
        return (await getApplicationSupportDirectory()).path;
      case CacheDirectoryType.caches:
        return (await getApplicationCacheDirectory()).path;
      case CacheDirectoryType.documents:
        return (await getApplicationDocumentsDirectory()).path;
      case CacheDirectoryType.library:
        if (Platform.isIOS || Platform.isMacOS) {
          return (await getLibraryDirectory()).path;
        } else {
          return (await getApplicationSupportDirectory()).path;
        }
      case CacheDirectoryType.customPath:
        if (customCachePath != null &&
            await Directory(customCachePath!).exists()) {
          return customCachePath!;
        } else {
          return (await getApplicationSupportDirectory()).path;
        }
    }
  }

  @override
  CacheDirectoryType get cacheDirectoryType => cacheDirectory;
}
