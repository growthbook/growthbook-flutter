import 'dart:developer';
import 'dart:io';

enum CacheDirectory {
  applicationSupport,
  caches,
  documents,
  library,
}

extension CacheDirectoryExtension on CacheDirectory {
  String get path {
    switch (this) {
      case CacheDirectory.applicationSupport:
        return 'application_support';
      case CacheDirectory.caches:
        return 'caches';
      case CacheDirectory.documents:
        return 'documents';
      case CacheDirectory.library:
        return 'library';
    }
  }
}

class CachingManager {
  static final CachingManager _instance = CachingManager._internal();

  factory CachingManager() {
    return _instance;
  }

  CachingManager._internal();

  late CacheDirectory _cacheDirectory;

  void updateCacheDirectory(CacheDirectory directory) {
    _cacheDirectory = directory;
  }

  String getTargetFile(String fileName) {
    String? directoryPath = _cacheDirectory.path;

    String targetFolderPath = '$directoryPath/GrowthBook-Cache';

    Directory(targetFolderPath).createSync(recursive: true);

    String file = fileName.replaceAll('.txt', '');

    return '$targetFolderPath/$file.txt';
  }

  void putData(String fileName, List<int> content) {
    saveContent(fileName, content);
  }

  void saveContent(String fileName, List<int> content) {
    File file = File(getTargetFile(fileName));
    file.writeAsBytesSync(content);
  }

  List<int>? getContent(String fileName) {
    File file = File(getTargetFile(fileName));
    if (file.existsSync()) {
      return file.readAsBytesSync();
    }
    return null;
  }

  void clearCache() {
    String? directoryPath = _cacheDirectory.path;

    String targetFolderPath = '$directoryPath/GrowthBook-Cache';
    Directory targetFolder = Directory(targetFolderPath);

    if (targetFolder.existsSync()) {
      try {
        targetFolder.deleteSync(recursive: true);
      } catch (e) {
        log('Failed to clear cache: $e');
      }
    } else {
      log('Cache directory does not exist. Nothing to clear.');
    }
  }
}
