/// Insertion-ordered LRU of the event keys sent recently.
///
/// A plain [Set] will not do: the cache has to evict the *oldest* key when it
/// is full, and a repeat has to move back to the newest position. Both are on
/// the hot path, because once an app settles and keeps re-evaluating the same
/// flags a duplicate hit is the common case.
///
/// Dart's default [Map] is insertion-ordered, so removing and re-inserting a
/// key moves it to the end and `keys.first` is the oldest — the ordering the
/// Swift SDK needs an intrusive linked list for comes for free here.
class DedupeCache {
  /// A capacity of zero disables deduping rather than dropping every event.
  DedupeCache(int capacity) : _capacity = capacity < 0 ? 0 : capacity;

  final int _capacity;
  final Map<String, bool> _keys = {};

  int get length => _keys.length;

  /// Records [key] and reports whether it had been seen recently. A hit becomes
  /// the newest entry, so a flag that keeps being evaluated never ages out
  /// while it is still in use.
  bool insertAndReportDuplicate(String key) {
    if (_capacity == 0) return false;

    if (_keys.remove(key) != null) {
      _keys[key] = true;
      return true;
    }

    _keys[key] = true;
    if (_keys.length > _capacity) {
      _keys.remove(_keys.keys.first);
    }
    return false;
  }

  /// Forgets [key], so the next identical event is reported rather than
  /// suppressed. Used when a batch fails to send: the events it carried were
  /// never delivered, so nothing has been said about them yet.
  void remove(String key) => _keys.remove(key);
}
