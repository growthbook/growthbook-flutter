import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

abstract class CachingLayer {

  GBFeatures? getContent(String key);
  void saveContent(String key, String value);
}


class CachingManager extends CachingLayer {
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

  getData(String fileName){
    return getContent(fileName);
  }

  void putData(String fileName, dynamic content){
    saveContent(fileName, content);
  }

  // Method to put data into the cache.
  @override
  void saveContent(String key, dynamic value) {
    // Store the data in the cache using the key.
    _cache[key] = value;
    log("_cache[key] ${_cache[key]}");
    final test = _cache[key];
    log(test.runtimeType.toString());
  }



  // Method to get data from the cache.
  @override
  GBFeatures? getContent(String key) {
    // Retrieve the data from the cache using the key.
    return _cache[key];
  }

  // Method to clear the cache (optional).
  void clearCache() {
    _cache.clear();
  }
}
