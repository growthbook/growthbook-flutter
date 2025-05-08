import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Utils/logger.dart';

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
  final _key = 'GrowthBook-Cache';

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
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final mapedContent = content.map((value) => value.toString());
      prefs.setStringList('$_key/$fileName', mapedContent.toList());
      return;
    }

    final fileManager = File(await getTargetFile(fileName));
    if (fileManager.existsSync()) {
      try {
        fileManager.deleteSync();
      } catch (e) {
        logger.e('Failed to remove file: $e');
      }
    }
    try {
      fileManager.writeAsBytesSync(content);
      logger.i('Content saved successfully to: $fileName');
    } catch (e) {
      logger.e('Failed to save content: $e');
    }
  }

  Future<String> getTargetFile(String fileName) async {
    final cacheDirectoryPath = localPath;
    String targetFolderPath = '$cacheDirectoryPath/$_key';
    final fileManager = Directory(targetFolderPath);
    if (!fileManager.existsSync()) {
      try {
        fileManager.createSync(recursive: true);
      } catch (e) {
        logger.e('Failed to create directory: $e');
      }
    }
    String file = fileName.replaceAll('.txt', '');

    return '$targetFolderPath/$file.txt';
  }

  String get localPath => Directory.systemTemp.path;

  @override
  Future<Uint8List?> getContent({required String fileName}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final result = prefs.getStringList('$_key/$fileName');
      final mapedResult = result?.map((value) => int.parse(value)).toList();
      if (mapedResult != null) return Uint8List.fromList(mapedResult);

      return null;
    }

    try {
      final filePath = await getTargetFile(fileName);
      File file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      logger.e('Failed to get content: $e');
    }
    return null;
  }

  Future<void> clearCache() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((value) => value.contains(_key));
      for (String key in keys) {
        prefs.remove(key);
      }
    }

    String cacheDirectoryPath = localPath;
    String targetFolderPath = '$cacheDirectoryPath/$_key';
    final fileManager = Directory(targetFolderPath);

    if (fileManager.existsSync()) {
      try {
        fileManager.deleteSync(recursive: true);
        logger.i('Cache cleared successfully.');
      } catch (e) {
        logger.e('Failed to clear cache: $e');
      }
    } else {
      logger.w('Cache directory does not exist. Nothing to clear.');
    }
  }
}
