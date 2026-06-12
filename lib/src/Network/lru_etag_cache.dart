import 'package:quiver/collection.dart';

class LruEtagCache {
  final LruMap<String, String?> _cache;

  LruEtagCache({int maxSize = 100}) : _cache = LruMap(maximumSize: maxSize);

  String? get(String url) => _cache[url];

  void put(String url, String? etag) {
    if (etag == null) {
      _cache.remove(url);
    } else {
      _cache[url] = etag;
    }
  }

  bool contains(String url) => _cache.containsKey(url);

  String? remove(String url) => _cache.remove(url);

  void clear() => _cache.clear();

  int size() => _cache.length;
}
