import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // The write is queued before the first await, so writes to one file run
    // in call order and never share its temp file, and a getContent or
    // removeContent called after putData waits for it.
    final targetPath = _targetFilePath(fileName);
    final write =
        _writeFile(_pendingWrites[targetPath], targetPath, fileName, content);
    _pendingWrites[targetPath] = write;
    await write;
    if (_pendingWrites[targetPath] == write) {
      _pendingWrites.remove(targetPath);
    }
  }

  final Map<String, Future<void>> _pendingWrites = {};

  Future<void> _writeFile(Future<void>? previousWrite, String targetPath,
      String fileName, Uint8List content) async {
    await previousWrite;
    await getTargetFile(fileName);
    final tempFile = File('$targetPath.tmp');

    try {
      // Write to temp file first
      await tempFile.writeAsBytes(content, flush: true);

      // Atomic rename — replaces target file safely
      await tempFile.rename(targetPath);

      logger.i('Content saved successfully to: $fileName');
    } catch (e) {
      logger.e('Failed to save content: $e');
      // Clean up temp file if it exists
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<String> getTargetFile(String fileName) async {
    try {
      await Directory(_targetFolderPath).create(recursive: true);
    } catch (e) {
      logger.e('Failed to create directory: $e');
    }

    return _targetFilePath(fileName);
  }

  String get _targetFolderPath => '$localPath/$_key';

  String _targetFilePath(String fileName) {
    String file = fileName.replaceAll('.txt', '');

    return '$_targetFolderPath/$file.txt';
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
      await _pendingWrites[_targetFilePath(fileName)];
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

  Future<void> removeContent({required String fileName}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_key/$fileName');
      return;
    }

    try {
      await _pendingWrites[_targetFilePath(fileName)];
      final filePath = await getTargetFile(fileName);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        logger.i('Cache file removed: $fileName');
      }
    } catch (e) {
      logger.e('Failed to remove content: $e');
    }
  }

  Future<void> clearCache() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((value) => value.contains(_key));
      for (String key in keys) {
        prefs.remove(key);
      }
    }

    await Future.wait(_pendingWrites.values);

    String cacheDirectoryPath = localPath;
    String targetFolderPath = '$cacheDirectoryPath/$_key';
    final fileManager = Directory(targetFolderPath);

    if (fileManager.existsSync()) {
      try {
        fileManager.deleteSync(recursive: true);
      } catch (e) {
        logger.e('Failed to clear cache: $e');
      }
    } else {
      logger.w('Cache directory does not exist. Nothing to clear.');
    }
  }
}
