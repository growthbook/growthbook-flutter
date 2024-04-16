import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

class CachingManager {
  // Create a static and final instance of the CachingManager class.
  static final CachingManager _instance = CachingManager._internal();

  // Define a private constructor.
  CachingManager._internal();

  // Create a factory constructor that returns the singleton instance.
  factory CachingManager() {
    return _instance;
  }

  // A map to hold the cached data.
  final Map<String, dynamic> _cache = {};

  // Method to put data into the cache.
  void putData(String key, dynamic data) {
    // Store the data in the cache using the key.
    _cache[key] = data;
    log("_cache[key] ${_cache[key]}");
    final test = _cache[key];
    log(test.runtimeType.toString());
  }

  // Method to get data from the cache.
  GBFeatures? getData(String key) {
    // Retrieve the data from the cache using the key.
    return _cache[key];
  }

  // Method to clear the cache (optional).
  void clearCache() {
    _cache.clear();
  }
}
