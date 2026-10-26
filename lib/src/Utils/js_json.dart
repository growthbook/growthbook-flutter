import 'dart:convert';

/// Formats [value] the way JavaScript's `String(number)` does.
///
/// Dart already matches JavaScript for most doubles, but writes integral
/// doubles with a trailing `.0` (`2.0`) and keeps the sign of `-0.0`.
/// JavaScript writes `2` and `0`.
String jsNumberToString(num value) {
  if (value is double &&
      value.isFinite &&
      value == value.truncateToDouble() &&
      value.abs() < 1e21) {
    return BigInt.from(value).toString();
  }
  return value.toString();
}

/// Encodes [value] the way JavaScript's `JSON.stringify` does, so two values
/// encode equally exactly when they would in JavaScript.
///
/// Numbers use [jsNumberToString] (so `1.0` and `1` encode the same), NaN and
/// infinities encode as `null`, and object keys that are array indexes come
/// first in ascending order, followed by the other keys in insertion order.
/// Throws a [JsonUnsupportedObjectError] for values JSON can't represent.
String jsJsonEncode(dynamic value) {
  if (value is num) {
    return value.isFinite ? jsNumberToString(value) : 'null';
  }
  if (value is List) {
    return '[${value.map(jsJsonEncode).join(',')}]';
  }
  if (value is Map) {
    final indexKeys = <String>[];
    final otherKeys = <String>[];
    final entries = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (!entries.containsKey(key)) {
        (_isArrayIndex(key) ? indexKeys : otherKeys).add(key);
      }
      entries[key] = entry.value;
    }
    indexKeys.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    final fields = [...indexKeys, ...otherKeys]
        .map((key) => '${jsonEncode(key)}:${jsJsonEncode(entries[key])}');
    return '{${fields.join(',')}}';
  }
  return jsonEncode(value);
}

/// Whether JavaScript treats [key] as an array index: a canonical
/// non-negative integer below 2^32 - 1.
bool _isArrayIndex(String key) {
  if (!RegExp(r'^(0|[1-9][0-9]{0,9})$').hasMatch(key)) return false;
  return int.parse(key) < 4294967295;
}
