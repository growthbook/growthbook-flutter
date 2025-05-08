import 'package:flutter/foundation.dart';

abstract class CachingLayer {
  Future<Uint8List?> getContent({required String fileName});
  void setCacheKey(String key);
  Future<void> saveContent({
    required String fileName,
    required Uint8List content,
  });
  Future<void> clearCache();
}