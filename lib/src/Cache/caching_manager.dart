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
/// `<cacheDir>/GrowthBook-Cache/<hashed-namespace>/<name>.txt`. On web, entries
/// are stored in `SharedPreferences` under the same
/// `GrowthBook-Cache/<hashed-namespace>/<name>` key shape.
///
/// Without a `namespace` the storage uses the pre-namespacing layout
/// `GrowthBook-Cache/<name>`, so data written by earlier SDK versions (such as
/// sticky bucket assignments) is still found.
///
/// The cache directory defaults to the platform's application cache directory
/// via `path_provider`, which persists across app launches on iOS, Android,
/// macOS, and Windows. Pass an explicit `cacheDirectory` to override.
class FileCacheStorage extends CacheStorage {
  static const _rootKey = 'GrowthBook-Cache';
  static final _namespacedWebKey = RegExp('^$_rootKey/[0-9a-f]{64}/');

  final String? _cacheDirectoryOverride;
  final String _cacheKey;

  String? _resolvedCacheDirectory;

  /// [namespace] isolates this instance's entries from other instances, e.g.
  /// `'<apiKey>|<hostURL>'`. It is stored hashed, never in plain text.
  FileCacheStorage({String? namespace, String? cacheDirectory})
      : _cacheDirectoryOverride = kIsWeb ? '' : cacheDirectory,
        _cacheKey = namespace != null ? _sha256Hash(namespace) : '';

  static String _sha256Hash(String input) {
    final inputBytes = utf8.encode(input);
    final digest = SHA256Digest().process(Uint8List.fromList(inputBytes));
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool get _isNamespaced => _cacheKey.isNotEmpty;

  /// Web key/prefix for this instance. Also used as the filesystem sub-path
  /// for the file-based backend so both backends share the same shape.
  String get _instancePrefix =>
      _isNamespaced ? '$_rootKey/$_cacheKey' : _rootKey;

  /// Where SDK versions before [FileCacheStorage] kept their files.
  String _legacyFilePath(String fileName) =>
      '${Directory.systemTemp.path}/$_rootKey/${fileName.replaceAll('.txt', '')}.txt';

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

    // The write is queued before the first await, so writes to one file run
    // in call order and never share its temp file, and a getContent or
    // removeContent called after saveContent waits for it.
    final key = _writeKey(fileName);
    final write = _writeFile(_pendingWrites[key], fileName, content);
    _pendingWrites[key] = write;
    await write;
    if (_pendingWrites[key] == write) {
      _pendingWrites.remove(key);
    }
  }

  /// Writes in flight, keyed by [_writeKey].
  ///
  /// Static because several instances can point at the same file (for
  /// example the un-namespaced storage of the SDK and of the sticky bucket
  /// service), and their writes must not share its temp file.
  static final Map<String, Future<void>> _pendingWrites = {};

  /// Key of a cache entry that is known without an await, unlike its path,
  /// which needs the cache directory from `path_provider`. Instances with the
  /// same prefix but different directories share a key; that only serialises
  /// their writes.
  String _writeKey(String fileName) =>
      '$_instancePrefix/${fileName.replaceAll('.txt', '')}';

  Future<void> _writeFile(
      Future<void>? previousWrite, String fileName, Uint8List content) async {
    await previousWrite;
    final targetPath = await getTargetFile(fileName);
    final tempFile = File('$targetPath.tmp');

    try {
      // Write to temp file first
      await tempFile.writeAsBytes(content, flush: true);

      // Atomic rename — replaces target file safely
      await tempFile.rename(targetPath);

      logger.i('Content saved successfully to: $fileName');
    } catch (e) {
      logger.e('Failed to save content: $e');
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<String> getTargetFile(String fileName) async {
    final cacheDirectoryPath = await _resolveCacheDirectory();
    final targetFolderPath = '$cacheDirectoryPath/$_instancePrefix';
    try {
      await Directory(targetFolderPath).create(recursive: true);
    } catch (e) {
      logger.e('Failed to create directory: $e');
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
      await _pendingWrites[_writeKey(fileName)];
      final filePath = await getTargetFile(fileName);
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return await _migrateLegacyFile(fileName, filePath);
    } catch (e) {
      logger.e('Failed to get content: $e');
    }
    return null;
  }

  /// Moves a file written by an earlier SDK version into the current location.
  ///
  /// Only the un-namespaced layout with the default directory is migrated:
  /// legacy feature caches were shared by every connection, so handing one to
  /// a namespaced instance could serve another connection's payload, and an
  /// explicit `cacheDirectory` never had a legacy location.
  Future<Uint8List?> _migrateLegacyFile(
      String fileName, String targetPath) async {
    if (_isNamespaced) return null;
    if (_cacheDirectoryOverride?.isNotEmpty ?? false) return null;

    final legacyFile = File(_legacyFilePath(fileName));
    if (legacyFile.absolute.path == File(targetPath).absolute.path) return null;
    if (!await legacyFile.exists()) return null;

    final content = await legacyFile.readAsBytes();
    await saveContent(fileName: fileName, content: content);
    // Deleted so a later removeContent() cannot be undone by migrating again.
    await legacyFile.delete();
    return content;
  }

  @override
  Future<void> removeContent({required String fileName}) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_instancePrefix/$fileName');
      return;
    }

    try {
      await _pendingWrites[_writeKey(fileName)];
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
          // The un-namespaced prefix is also the parent of every namespace.
          .where((k) => _isNamespaced || !_namespacedWebKey.hasMatch(k))
          .toList();
      await Future.wait(scopedKeys.map(prefs.remove));
      return;
    }

    // Deleting files while a write is still running in the folder fails or
    // lets the write put a file back after the clear.
    await Future.wait(_pendingWrites.values);

    final cacheDirectoryPath = await _resolveCacheDirectory();
    final targetFolderPath = '$cacheDirectoryPath/$_instancePrefix';
    final directory = Directory(targetFolderPath);

    if (!directory.existsSync()) {
      logger.w('Cache directory does not exist. Nothing to clear.');
      return;
    }

    try {
      if (_isNamespaced) {
        directory.deleteSync(recursive: true);
      } else {
        // Namespaced instances live in subdirectories; leave them alone.
        for (final entity in directory.listSync()) {
          if (entity is File) entity.deleteSync();
        }
      }
    } catch (e) {
      logger.e('Failed to clear cache: $e');
    }
  }
}
