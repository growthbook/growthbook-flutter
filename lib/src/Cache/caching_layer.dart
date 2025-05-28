import 'package:flutter/foundation.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

abstract class CachingLayer {
  Future<Uint8List?> getContent({required String fileName});
  void setCacheKey(String key);
  Future<void> saveContent({
    required String fileName,
    required Uint8List content,
  });
  Future<void> clearCache();
  void setCacheDirectory(CacheDirectoryWrapper directory);
}