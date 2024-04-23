import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';

abstract class CachingLayer {
  Future<Uint8List?> getContent({required String fileName});
  Future<void> saveContent({
    required String fileName,
    required Uint8List content,
  });
}

class CachingManager extends CachingLayer {
  static final CachingManager _instance = CachingManager._internal();
  CachingManager._internal();

  factory CachingManager() {
    return _instance;
  }

  Future<Uint8List?> getData({required String fileName}) {
    return getContent(fileName: fileName);
  }

  void putData({
    required String fileName,
    required Uint8List content,
  }) {
    saveContent(fileName: fileName, content: content);
  }

  @override
  Future<void> saveContent({
    required String fileName,
    required Uint8List content,
  }) async {
    final fileManager = File(await getTargetFile(fileName));
    if (fileManager.existsSync()) {
      try {
        fileManager.deleteSync();
      } catch (e) {
        log('Failed to remove file: $e');
      }
    }
    try {
      fileManager.writeAsBytesSync(content);
      log('Content saved successfully to: $fileName');
    } catch (e) {
      log('Failed to save content: $e');
    }
  }

  Future<String> getTargetFile(String fileName) async {
    final cacheDirectoryPath = localPath;
    String targetFolderPath = '$cacheDirectoryPath/GrowthBook-Cache';
    var fileManager = Directory(targetFolderPath);
    if (!fileManager.existsSync()) {
      try {
        fileManager.createSync(recursive: true);
      } catch (e) {
        log('Failed to create directory: $e');
      }
    }
    String file = fileName.replaceAll('.txt', '');

    return '$targetFolderPath/$file.txt';
  }

  String get localPath => Directory.systemTemp.path;

  @override
  Future<Uint8List?> getContent({required String fileName}) async {
    try {
      final filePath = await getTargetFile(fileName);
      File file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      log('Failed to get content: $e');
    }
    return null;
  }

  Future<void> clearCache() async {
    String cacheDirectoryPath = localPath;
    String targetFolderPath = '$cacheDirectoryPath/GrowthBook-Cache';
    final fileManager = Directory(targetFolderPath);

    if (fileManager.existsSync()) {
      try {
        fileManager.deleteSync(recursive: true);
      } catch (e) {
        log('Failed to clear cache: $e');
      }
    } else {
      log('Cache directory does not exist. Nothing to clear.');
    }
  }
}
