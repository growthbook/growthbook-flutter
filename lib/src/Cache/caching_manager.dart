import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage backend for GrowthBook's on-device cache. Implement this to plug in
/// a custom store (in-memory, encrypted, remote-backed, etc.) via
/// `GBSDKBuilderApp(cacheStorage: MyStorage())`.
abstract class CacheStorage {
  Future<void> saveContent({
    required String fileName,
    required Uint8List content,
  });
  Future<Uint8List?> getContent({required String fileName});
  Future<void> removeContent({required String fileName});
  Future<void> clearCache();
}

/// Default `CacheStorage` implementation.
///
/// Non-web platforms write bytes to files under
/// `<cacheDir>/GrowthBook-Cache/<hashed-api-key>/<name>.txt`. On web, entries
/// are stored in `SharedPreferences` under the same
/// `GrowthBook-Cache/<hashed-api-key>/<name>` key shape.
///
/// The cache directory defaults to the platform's application cache directory
/// via `path_provider`, which persists across app launches on iOS, Android,
/// macOS, and Windows. Pass an explicit `cacheDirectory` to override.
class FileCacheStorage extends CacheStorage {
  static const _rootKey = 'GrowthBook-Cache';

  final String? _cacheDirectoryOverride;
  final String _cacheKey;

  String? _resolvedCacheDirectory;

  FileCacheStorage({String? apiKey, String? cacheDirectory})
      : _cacheDirectoryOverride = kIsWeb ? '' : cacheDirectory,
        _cacheKey = apiKey != null ? _sha256Hash(apiKey) : '';

  static String _sha256Hash(String input) {
    final inputBytes = utf8.encode(input);
    final digest = SHA256Digest().process(Uint8List.fromList(inputBytes));
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Web key/prefix for this instance. Also used as the filesystem sub-path
  /// segment `<_rootKey>/<_cacheKey>` for the file-based backend so both
  /// backends share the same namespace shape.
  String get _instancePrefix => '$_rootKey/$_cacheKey';

  Future<String> _resolveCacheDirectory() async {
    final override = _cacheDirectoryOverride;
    if (override != null && override.isNotEmpty) return override;
    final cached = _resolvedCacheDirectory;
    if (cached != null) return cached;
    try {
      final dir = await getApplicationCacheDirectory();
      _resolvedCacheDirectory = dir.path;
    } catch (e) {
      // path_provider not available (e.g. unit tests without a Flutter test
      // binding). Fall back to system temp so callers still get a usable dir.
      logger.w('path_provider unavailable, using system temp: $e');
      _resolvedCacheDirectory = Directory.systemTemp.path;
    }
    return _resolvedCacheDirectory!;
  }

  Future<Uint8List?> getData({required String fileName}) {
    return getContent(fileName: fileName);
  }

  @Deprecated('Use saveContent instead')
  Future<void> putData({
    required String fileName,
    required Uint8List content,
  }) {
    return saveContent(fileName: fileName, content: content);
  }

  @override
  Future<void> saveContent({
    required String fileName,
    required Uint8List content,
  }) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final mapedContent = content.map((value) => value.toString()).toList();
      await prefs.setStringList('$_instancePrefix/$fileName', mapedContent);
      return;
    }

    final targetPath = await getTargetFile(fileName);
    final tempFile = File('$targetPath.tmp');

    try {
      tempFile.writeAsBytesSync(content, flush: true);
      tempFile.renameSync(targetPath);
      logger.i('Content saved successfully to: $fileName');
    } catch (e) {
      logger.e('Failed to save content: $e');
      try {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      } catch (_) {}
    }
  }

  Future<String> getTargetFile(String fileName) async {
    final cacheDirectoryPath = await _resolveCacheDirectory();
    final targetFolderPath = '$cacheDirectoryPath/$_instancePrefix';
    final directory = Directory(targetFolderPath);
    if (!directory.existsSync()) {
      try {
        directory.createSync(recursive: true);
      } catch (e) {
        logger.e('Failed to create directory: $e');
      }
    }
    final file = fileName.replaceAll('.txt', '');
    return '$targetFolderPath/$file.txt';
  }

  @override
  Future<Uint8List?> getContent({required String fileName}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final result = prefs.getStringList('$_instancePrefix/$fileName');
      final mapedResult = result?.map((value) => int.parse(value)).toList();
      if (mapedResult != null) return Uint8List.fromList(mapedResult);
      return null;
    }

    try {
      final filePath = await getTargetFile(fileName);
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      logger.e('Failed to get content: $e');
    }
    return null;
  }

  @override
  Future<void> removeContent({required String fileName}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_instancePrefix/$fileName');
      return;
    }

    try {
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

  @override
  Future<void> clearCache() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      // Scope to this instance's namespace only — otherwise clearing one SDK
      // instance would wipe caches for every other API key on the same origin.
      final scopedKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('$_instancePrefix/'))
          .toList();
      await Future.wait(scopedKeys.map(prefs.remove));
      return;
    }

    final cacheDirectoryPath = await _resolveCacheDirectory();
    final targetFolderPath = '$cacheDirectoryPath/$_instancePrefix';
    final directory = Directory(targetFolderPath);

    if (directory.existsSync()) {
      try {
        directory.deleteSync(recursive: true);
      } catch (e) {
        logger.e('Failed to clear cache: $e');
      }
    } else {
      logger.w('Cache directory does not exist. Nothing to clear.');
    }
  }
}
