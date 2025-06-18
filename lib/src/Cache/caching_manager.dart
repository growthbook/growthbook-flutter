import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class CacheStorage {
  Future<void> saveContent({
    required String fileName,
    required Uint8List content,
  });
  Future<Uint8List?> getContent({required String fileName});
  Future<void> clearCache();
}

class FileCacheStorage extends CacheStorage {
  final _key = 'GrowthBook-Cache';
  final String _cacheDirectory;

  String _cacheKey = '';

  FileCacheStorage({String? apiKey, String? cacheDirectory})
      : _cacheDirectory = kIsWeb
            ? '' 
            : (cacheDirectory ?? Directory.systemTemp.path) {
    if (apiKey != null) {
      setCacheKey(apiKey);
    }
  }

  void setCacheKey(String key) {
    _cacheKey = _sha256Hash(key);
  }

  String _sha256Hash(String input) {
    final inputBytes = utf8.encode(input);
    final digest = SHA256Digest().process(Uint8List.fromList(inputBytes));

    final hashString =
        digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return hashString.substring(0, 5);
  }

  Future<Uint8List?> getData({required String fileName}) {
    return getContent(fileName: fileName);
  }

  @deprecated
  /// Deprecated. Use [saveContent] instead.
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
      prefs.setStringList('$_key/$_cacheKey/$fileName', mapedContent.toList());
      return;
    }

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
    final cacheDirectoryPath = _cacheDirectory;
    String targetFolderPath = '$cacheDirectoryPath/$_key/$_cacheKey';
    final fileManager = Directory(targetFolderPath);
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

  @override
  Future<Uint8List?> getContent({required String fileName}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final result = prefs.getStringList('$_key/$_cacheKey/$fileName');
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
      log('Failed to get content: $e');
    }
    return null;
  }

  @override
  Future<void> clearCache() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((value) => value.contains(_key));
      for (String key in keys) {
        prefs.remove(key);
      }
      return;
    }

    final cacheDirectoryPath = _cacheDirectory;
    String targetFolderPath = '$cacheDirectoryPath/$_key/$_cacheKey';
    final fileManager = Directory(targetFolderPath);

    if (fileManager.existsSync()) {
      try {
        fileManager.deleteSync(recursive: true);
      } catch (e) {
        log('Failed to clear cache: $e');
      }
    } else {
      log('Cache directory does not exist. Nothing to clear.');
      print(targetFolderPath);
    }
  }
}
