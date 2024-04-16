import 'dart:convert';

import 'package:growthbook_sdk_flutter/src/Model/context.dart';
import 'package:growthbook_sdk_flutter/src/Utils/utils.dart';

/// Fowler-Noll-Vo hash - 32 bit
class FNV {
  final BigInt _int32 = BigInt.from(0x811c9dc5);
  final BigInt _prime32 = BigInt.from(0x01000193);
  final BigInt _mode32 = BigInt.from(2).pow(32);

  BigInt fnv1a_32(String data) {
    var hash = _int32;
    for (var b in data.split('')) {
      hash = hash ^ BigInt.from(b.codeUnitAt(0) & 0xff);
      hash = (hash * _prime32).modPow(BigInt.one, _mode32);
    }
    return hash;
  }
}

/// GrowthBook Utils Class
/// Contains Methods for
/// - hash
/// - inNameSpace
/// - getEqualWeights
/// - getBucketRanges
/// - chooseVariation
/// - getGBNameSpace
/// - inRange
/// - isFilteredOut
/// - isIncludedInRollout
class GBUtils {
  const GBUtils();

  /// Hashes a string to a float between 0 and 1
  /// fnv32a returns an integer, so we convert that to a float using a modulus:

  static double? hash({
    required String seed,
    required String value,
    required double version,
  }) {
    if (version == 2) {
      // New unbiased hashing algorithm
      final combinedValue = seed + value;
      final firstHash = FNV().fnv1a_32(combinedValue);
      final secondHash = FNV().fnv1a_32(firstHash.toString());

      final remainder = secondHash.remainder(BigInt.from(10000));
      final hashedValue = remainder.toDouble() / 10000.0;
      return hashedValue;
    }
    if (version == 1) {
      // Original biased hashing algorithm (keep for backwards compatibility)
      final combinedValue = value + seed;
      final hash = FNV().fnv1a_32(combinedValue);
      final remainder = hash.remainder(BigInt.from(1000));
      final hashedValue = remainder.toDouble() / 1000.0;
      return hashedValue;
    }
    // Unknown hash version
    return null;
  }

  /// This checks if a userId is within an experiment namespace or not.
  static bool inNamespace(String userId, GBNameSpace namespace) {
    final hashValue =
        hash(value: "${userId}__", seed: namespace.item1, version: 1.0);
    if (hashValue == null) return false;
    return hashValue >= namespace.item2 && hashValue < namespace.item3;
  }

  /// Returns an array of double with numVariations items that are all equal and
  /// sum to 1. For example, getEqualWeights(2) would return [0.5, 0.5]

  static List<double> getEqualWeights(int numVariations) {
    if (numVariations <= 0) return [];
    return List.filled(numVariations, 1.0 / numVariations);
  }

  ///This converts and experiment's coverage and variation weights into an array
  /// of bucket ranges.
  static List<GBBucketRange> getBucketRanges(
      int numVariations, double coverage, List<double>? weights) {
    // Clamp the value of coverage to between 0 and 1 inclusive.
    double targetCoverage = coverage.clamp(0, 1);

    // Default to equal weights if the weights don't match the number of variations.
    final equal = getEqualWeights(numVariations);
    var targetWeights = weights ?? equal;
    if (targetWeights.length != numVariations) {
      targetWeights = equal;
    }

    // Default to equal weights if the sum is not equal 1 (or close enough when
    // rounding errors are factored in):
    final weightsSum =
        targetWeights.fold<double>(0, (prev, element) => prev + element);
    if (weightsSum < 0.99 || weightsSum > 1.01) {
      targetWeights = equal;
    }

    // Convert weights to ranges and return
    var cumulative = 0.0;
    List<GBBucketRange> bucketRange = [];

    for (var i = 0; i < numVariations; i++) {
      var start = cumulative;
      cumulative += targetWeights[i];
      var end = cumulative;

      // Adjust the end based on target coverage
      end = start + targetCoverage * (end - start);

      // Round to 4 decimal places
      start = start.roundTo(4);
      end = end.roundTo(4);

      bucketRange.add(GBBucketRange(start, end));
    }

    return bucketRange;
  }

  int chooseVariation(double n, List<GBBucketRange> ranges) {
    for (int index = 0; index < ranges.length; index++) {
      if (inRange(n, ranges[index])) {
        return index;
      }
    }
    return -1;
  }

  ///Convert JsonArray to GBNameSpace
  static GBNameSpace? getGBNameSpace(List namespace) {
    if (namespace.length >= 3) {
      final title = namespace[0];
      final start = namespace[1];
      final end = namespace[2];

      if (start != null && end != null) {
        return GBNameSpace(title, double.parse(start.toString()),
            double.parse(end.toString()));
      }
    }

    return null;
  }

  /// Determines if a number n is within the provided range.
  static bool inRange(double? n, GBBucketRange? range) {
    return n != null && range != null && n >= range.item1 && n < range.item2;
  }

  /// This is a helper method to evaluate filters for both feature flags and experiments.
  static bool isFilteredOut(List<GBFilter>? filters, dynamic attributes) {
    if (filters == null) return false;
    if (attributes == null) return false;
    return filters.any((filter) {
      String hashAttribute = filter.attribute ?? "id";
      dynamic hashValueElement = attributes[hashAttribute];
      if (hashValueElement == null) return true;

      if (!(hashValueElement is int ||
          hashValueElement is double ||
          hashValueElement is String ||
          hashValueElement is bool)) {
        return true;
      }

      String hashValue = hashValueElement.toString();
      if (hashValue.isEmpty) return true;
      int hashVersion = filter.hashVersion ?? 2;
      final n = hash(
          value: hashValue, version: hashVersion.toDouble(), seed: filter.seed);
      if (n == null) return true;
      final ranges = filter.ranges;
      return ranges.every((range) => !inRange(n, range));
    });
  }

  /// Determines if the user is part of a gradual feature rollout.
  static bool isIncludedInRollout(
    dynamic attributes,
    String? seed,
    String? hashAttribute,
    GBBucketRange? range,
    double? coverage,
    int? hashVersion,
  ) {
    String? latestHashAttribute = hashAttribute;
    int? latestHashVersion = hashVersion;
    if (range == null && coverage == null) return true;
    if (hashAttribute == null || hashAttribute == '') {
      latestHashAttribute = 'id';
    }
    if (attributes == null) return false;
    dynamic hashValueElement = jsonEncode(attributes[latestHashAttribute]);
    if (hashValueElement == null) return false;
    if (hashVersion == null) {
      latestHashVersion = 1;
    }
    String hashValue = jsonEncode(hashValueElement);
    final hashResult = hash(
        value: hashValue,
        version: latestHashVersion!.toDouble(),
        seed: seed ?? '');
    if (hashResult == null) return false;
    return range != null ? inRange(hashResult, range) : hashResult <= coverage!;
  }

  static String paddedVersionString(String input) {
    // "v1.2.3-rc.1+build123" -> ["1","2","3","rc","1"]
    List<String> parts =
        input.replaceAll(RegExp(r'^v|\+.*$'), '').split(RegExp(r'[-.]'));

    // ["1","0","0"] -> ["1","0","0","~"]
    // "~" is the largest ASCII character, so this will make "1.0.0" greater than "1.0.0-beta" for example
    if (parts.length == 3) {
      List<String> arrayList = List.from(parts);
      arrayList.add("~");
      parts = arrayList;
    }

    // Left pad each numeric part with spaces so string comparisons will work
    for (int i = 0; i < parts.length; i++) {
      if (RegExp(r'^\d+$').hasMatch(parts[i])) {
        parts[i] = parts[i].padLeft(5, ' ');
      }
    }

    // Then, join back together into a single string
    return parts.join('-');
  }

  static List<String> getHashAttribute({
    required GBContext context,
    String? attr,
    String? fallback,
    required Map<String, dynamic> attributeOverrides,
  }) {
    String hashAttribute = attr ?? 'id';
    String hashValue = '';

    if (attributeOverrides.containsKey(hashAttribute) &&
        attributeOverrides[hashAttribute] != null) {
      hashValue = attributeOverrides[hashAttribute];
    } else if (context.attributes!.containsKey(hashAttribute) &&
        context.attributes?[hashAttribute] != null) {
      hashValue = context.attributes?[hashAttribute];
    }

    if (hashValue.isEmpty && fallback != null) {
      if (attributeOverrides.containsKey(fallback) &&
          attributeOverrides[fallback] != null) {
        hashValue = attributeOverrides[fallback];
      } else if (context.attributes!.containsKey(fallback) &&
          context.attributes?[fallback] != null) {
        hashValue = context.attributes?[fallback];
      }

      if (hashValue.isNotEmpty) {
        hashAttribute = fallback;
      }
    }

    return [hashAttribute, hashValue];
  }
}
