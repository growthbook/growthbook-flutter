import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Network/lru_etag_cache.dart';

void main() {
  test('ETag cache stores and retrieves values', () {
    final cache = LruEtagCache(maxSize: 2);

    cache.put("a", "123");
    cache.put("b", "456");

    expect(cache.get("a"), "123");
    expect(cache.get("b"), "456");
  });

  test('ETag cache evicts least recently used item', () {
    final cache = LruEtagCache(maxSize: 2);

    cache.put("a", "123");
    cache.put("b", "456");
    cache.put("c", "789"); // LRU = "a"

    expect(cache.get("a"), isNull);
    expect(cache.get("b"), "456");
    expect(cache.get("c"), "789");
  });
}
