import 'package:growthbook_sdk_flutter/src/Evaluator/experiment_evaluator.dart';
import 'package:growthbook_sdk_flutter/src/Model/context.dart';
import 'package:growthbook_sdk_flutter/src/Model/features_model.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_filter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_variation_meta.dart';
import 'package:growthbook_sdk_flutter/src/Utils/utils.dart';

/// Fowler-Noll-Vo hash - 32 bit
class FNV {
  // Constants for FNV-1a 32-bit hash
  final int init32 = 0x811c9dc5;
  final int prime32 = 0x01000193;
  final int mod32 = 0x100000000; // Equivalent to 2^32

  /// Fowler-Noll-Vo hash - 32 bit
  /// Returns an integer representing the hash.
  int fnv1a32(String data) {
    int hash = init32;
    for (int i = 0; i < data.length; i++) {
      int b = data.codeUnitAt(i) & 0xff; // Get the ASCII value of the character
      hash ^= b; // XOR the hash with the character's value
      hash = (hash * prime32) % mod32; // Multiply by prime and mod with mod32
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
    required int version,
  }) {
    if (version == 2) {
      // New unbiased hashing algorithm
      final combinedValue = seed + value;
      final firstHash = FNV().fnv1a32(combinedValue);
      final secondHash = FNV().fnv1a32(firstHash.toString());

      final remainder = secondHash.remainder(BigInt.from(10000).toDouble());
      final hashedValue = remainder.toDouble() / 10000.0;
      return hashedValue;
    }
    if (version == 1) {
      // Original biased hashing algorithm (keep for backwards compatibility)
      final combinedValue = value + seed;
      final hash = FNV().fnv1a32(combinedValue);
      final remainder = hash.remainder(BigInt.from(1000).toDouble());
      final hashedValue = remainder.toDouble() / 1000.0;
      return hashedValue;
    }
    // Unknown hash version
    return null;
  }

  /// This checks if a userId is within an experiment namespace or not.
  static bool inNamespace(String userId, GBNameSpace namespace) {
    final hashValue = hash(value: "${userId}__", seed: namespace.item1, version: 1);
    if (hashValue == null) return false;
    return hashValue >= namespace.item2 && hashValue < namespace.item3;
  }

  /// Returns an array of double with numVariations items that are all equal and
  /// sum to 1. For example, getEqualWeights(2) would return [0.5, 0.5].
  static List<double> getEqualWeights(int numVariations) {
    List<double> weights = <double>[];

    if (numVariations >= 1) {
      weights = List.filled(numVariations, 1 / numVariations);
    }

    return weights;
  }

  ///This converts and experiment's coverage and variation weights into an array
  /// of bucket ranges.
  static List<GBBucketRange> getBucketRanges(int numVariations, double coverage, List<double>? weights) {
    List<List<double>> bucketRanges = [];
    var targetCoverage = coverage;

    // Clamp the value of coverage to between 0 and 1 inclusive.
    if (coverage < 0) {
      targetCoverage = 0;
    }
    if (coverage > 1) {
      targetCoverage = 1;
    }

    // Default to equal weights if the weights don't match the number of variations
    List<double> equalWeights = getEqualWeights(numVariations);
    List<double> targetWeights = weights ?? equalWeights;
    if (targetWeights.length != numVariations) {
      targetWeights = equalWeights;
    }

    // Calculate the sum of target weights
    double weightsSum = targetWeights.fold<double>(0, (prev, element) => prev + element);
    // targetWeights.reduce(0.0, (sum, weight) => sum + weight);

    // If the sum of weights is not close to 1, default to equal weights
    if (weightsSum < 0.99 || weightsSum > 1.01) {
      targetWeights = equalWeights;
    }

    // Convert weights to ranges
    double cumulative = 0.0;
    for (double weight in targetWeights) {
      double start = cumulative;
      cumulative += weight;
      double end = start + (targetCoverage * weight);

      // Add the bucket range to the list, rounded to 4 decimal places
      bucketRanges.add([start.roundTo(4), end.roundTo(4)]);
    }

    return bucketRanges;
  }

  int chooseVariation(double n, List<List<double>> ranges) {
    // Iterate through the list of ranges with index
    for (int index = 0; index < ranges.length; index++) {
      // Get the current range (a list of two doubles)
      List<double> range = ranges[index];

      // Check if the current range contains the value `n`
      if (n >= range[0] && n < range[1]) {
        // If `n` is within the range, return the index
        return index;
      }
    }

    // If no range contains `n`, return `-1`
    return -1;
  }

  ///Convert JsonArray to GBNameSpace
  static GBNameSpace? getGBNameSpace(List namespace) {
    if (namespace.length >= 3) {
      final title = namespace[0];
      final start = namespace[1];
      final end = namespace[2];

      if (start != null && end != null) {
        return GBNameSpace(title, double.parse(start.toString()), double.parse(end.toString()));
      }
    }

    return null;
  }

  /// Determines if a number n is within the provided range.
  static bool inRange(double n, List<double> range) {
    return n >= range[0] && n < range[1];
  }

  /// This is a helper method to evaluate filters for both feature flags and experiments.
  static bool isFilteredOut(
    List<GBFilter> filters,
    GBContext context,
    Map<String, dynamic> attributeOverrides,
  ) {
    return filters.any((filter) {
      final hashAttributeAndValue = GBUtils.getHashAttribute(
        context: context,
        attr: filter.attribute,
        attributeOverrides: attributeOverrides,
      );
      final hashValue = hashAttributeAndValue[1];

      final hash = GBUtils.hash(
        seed: filter.seed,
        value: hashValue,
        version: filter.hashVersion,
      );

      if (hash == null) {
        return true;
      }

      return !filter.ranges.any((range) {
        return GBUtils.inRange(hash, range);
      });
    });
  }

  static bool isIncludedInRollout(Map<dynamic, dynamic> attributeOverrides, String? seed, String? hashAttribute,
      String? fallbackAttribute, GBBucketRange? range, double? coverage, int? hashVersion, GBContext context) {
    // If both range and coverage are null, return true
    if (range == null && coverage == null) return true;

    if (range == null && coverage == 0) return false;

    // Get the hash attribute and its value
    var hashAttrResult = getHashAttribute(
        attr: hashAttribute, fallback: fallbackAttribute, attributeOverrides: attributeOverrides, context: context);
    String? hashValue = hashAttrResult[1];

    // Calculate the hash
    double? hash = hashFunction(
      hashValue,
      hashVersion ?? 1,
      seed,
    );

    // If hash is null, return false
    if (hash == null) return false;

    // Check the range or coverage conditions
    if (range != null) {
      return inRange(hash, range);
    } else if (coverage != null) {
      return hash <= coverage;
    } else {
      return true;
    }
  }

  static String paddedVersionString(String input) {
    // "v1.2.3-rc.1+build123" -> ["1","2","3","rc","1"]
    List<String> parts = input.replaceAll(RegExp(r'^v|\+.*$'), '').split(RegExp(r'[-.]'));

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

  /// Returns a tuple of two elements: the attribute itself and its hash value.
  static List<String> getHashAttribute({
    required GBContext context,
    String? attr,
    String? fallback,
    required Map<dynamic, dynamic> attributeOverrides,
  }) {
    String hashAttribute = attr ?? 'id';
    String hashValue = '';

    if (attributeOverrides.containsKey(hashAttribute) && attributeOverrides[hashAttribute] != null) {
      hashValue = attributeOverrides[hashAttribute].toString();
    } else if (context.attributes != null &&
        context.attributes!.containsKey(hashAttribute) &&
        context.attributes![hashAttribute] != null) {
      hashValue = context.attributes![hashAttribute].toString();
    }

    // If no match, try fallback
    if (hashValue.isEmpty && fallback != null) {
      if (attributeOverrides.containsKey(fallback) && attributeOverrides[fallback] != null) {
        hashValue = attributeOverrides[fallback].toString();
      } else if (context.attributes != null &&
          context.attributes!.containsKey(fallback) &&
          context.attributes![fallback] != null) {
        hashValue = context.attributes![fallback].toString();
      }

      if (hashValue.isNotEmpty) {
        hashAttribute = fallback;
      }
    }

    return [hashAttribute, hashValue];
  }

  static double? hashFunction(
    String stringValue,
    int? hashVersion,
    String? seed,
  ) {
    // Return null if hashVersion is null
    if (hashVersion == null) {
      return null;
    }

    // Check the hash version and calculate the hash accordingly
    switch (hashVersion) {
      case 1:
        return hashV1(stringValue, seed);
      case 2:
        return hashV2(stringValue, seed);
      default:
        return null;
    }
  }

  static double hashV1(String stringValue, String? seed) {
    FNV fnv = FNV();
    // Combine stringValue and seed, then calculate the FNV-1a 32-bit hash
    int bigInt = fnv.fnv1a32(stringValue + (seed ?? ''));

    // Calculate the remainder when bigInt is divided by 1000
    int thousand = 1000;
    int remainder = bigInt % thousand;

    // Convert remainder to float and divide by 1000
    double remainderAsFloat = remainder.toDouble();
    return remainderAsFloat / 1000.0;
  }

  static double hashV2(String stringValue, String? seed) {
    FNV fnv = FNV();
    // Calculate the FNV-1a 32-bit hash of seed + stringValue
    int first = fnv.fnv1a32((seed ?? '') + stringValue);

    // Calculate the FNV-1a 32-bit hash of the string representation of the first hash
    int second = fnv.fnv1a32(first.toString());

    // Calculate the remainder when second is divided by 10000
    int tenThousand = 10000;
    int remainder = second % tenThousand;

    // Convert remainder to float and divide by 10000
    double remainderAsFloat = remainder.toDouble();
    return remainderAsFloat / 10000.0;
  }

  static Map<String, String> getStickyBucketAssignments({
    required GBContext context,
    required String? expHashAttribute,
    required String? expFallBackAttribute,
    required Map<dynamic, dynamic> attributeOverrides,
  }) {
    final assignments = <String, String>{};

    Map<StickyAttributeKey, StickyAssignmentsDocument>? stickyBucketAssignmentDocs =
        <StickyAttributeKey, StickyAssignmentsDocument>{};

    // Check if stickyBucketAssignmentDocs is null
    if (context.stickyBucketAssignmentDocs == null) {
      return assignments;
    } else {
      stickyBucketAssignmentDocs = context.stickyBucketAssignmentDocs;
    }

    // Retrieve hashAttributeAndValue and hashKey
    final hashAttributeAndValue = getHashAttribute(
      context: context,
      attr: expHashAttribute,
      fallback: null,
      attributeOverrides: attributeOverrides,
    );

    final hashKey = '${hashAttributeAndValue[0]}||${hashAttributeAndValue[1]}';

    // Retrieve fallbackAttributeAndValue and fallbackKey
    final fallbackAttributeAndValue = getHashAttribute(
      context: context,
      attr: expFallBackAttribute,
      fallback: null,
      attributeOverrides: attributeOverrides,
    );

    String? fallbackKey;

    if (fallbackAttributeAndValue[1].isEmpty) {
      fallbackKey = null;
    } else {
      "${fallbackAttributeAndValue[0]}||${fallbackAttributeAndValue[1]}";
    }

    String? leftOperand = context
        .stickyBucketAssignmentDocs?["$expFallBackAttribute||${attributeOverrides[expFallBackAttribute]}"]
        ?.attributeValue;

    if (leftOperand != attributeOverrides[expFallBackAttribute]) {
      context.stickyBucketAssignmentDocs = {};
    }

    // Add assignments from stickyBucketAssignmentDocs
    context.stickyBucketAssignmentDocs?.forEach((key, doc) {
      assignments.addAll(doc.assignments);
    });

    // Add assignments from fallbackKey if not null
    if (fallbackKey != null && stickyBucketAssignmentDocs?[fallbackKey] != null) {
      assignments.addAll(stickyBucketAssignmentDocs?[fallbackKey]?.assignments ?? {});
    }

    // Add assignments from hashKey if not null
    if (stickyBucketAssignmentDocs?[hashKey] != null) {
      assignments.addAll(stickyBucketAssignmentDocs![hashKey]?.assignments ?? {});
    }

    return assignments;
  }

  static Future<void> refreshStickyBuckets(
    GBContext context,
    FeaturedDataModel? data,
    Map<dynamic, dynamic> attributeOverrides,
  ) async {
    if (context.stickyBucketService == null) {
      return;
    }
    var attributes = getStickyBucketAttributes(context, data, attributeOverrides);
    context.stickyBucketAssignmentDocs = await context.stickyBucketService?.getAllAssignments(attributes);
  }

  static Map<String, String> getStickyBucketAttributes(
    GBContext context,
    FeaturedDataModel? data,
    Map<dynamic, dynamic> attributeOverrides,
  ) {
    var attributes = <String, String>{};
    context.stickyBucketIdentifierAttributes = context.stickyBucketIdentifierAttributes != null
        ? GBUtils.deriveStickyBucketIdentifierAttributes(context: context, data: data)
        : context.stickyBucketIdentifierAttributes;
    context.stickyBucketIdentifierAttributes?.forEach((attr) {
      var hashValue = GBUtils.getHashAttribute(context: context, attributeOverrides: attributeOverrides, attr: attr);
      attributes[attr] = hashValue[1];
    });
    return attributes;
  }

  static List<String> deriveStickyBucketIdentifierAttributes({
    required GBContext context,
    required FeaturedDataModel? data,
  }) {
    var attributes = <String>{};
    var features = data?.features ?? context.features;
    for (var id in features.keys) {
      var feature = features[id];
      var rules = feature?.rules;
      rules?.forEach((rule) {
        var variations = rule.variations;
        variations?.forEach((variation) {
          attributes.add(rule.hashAttribute ?? "id");
          if (rule.fallbackAttribute != null) {
            attributes.add(rule.fallbackAttribute!);
          }
        });
      });
    }
    return attributes.toList();
  }

  static StickyBucketResult getStickyBucketVariation({
    required GBContext context,
    required String experimentKey,
    required int experimentBucketVersion,
    required int minExperimentBucketVersion,
    required List<GBVariationMeta> meta,
    required String expHashAttribute,
    required String? expFallBackAttribute,
    required Map<dynamic, dynamic> attributeOverrides,
  }) {
    // Get the assignment key for the given experiment key and version.
    final assignmentKey = getStickyBucketExperimentKey(experimentKey, experimentBucketVersion);
    // Fetch all sticky bucket assignments from the context.
    final assignments = getStickyBucketAssignments(
      context: context,
      expHashAttribute: expHashAttribute,
      expFallBackAttribute: expFallBackAttribute,
      attributeOverrides: attributeOverrides,
    );

    // Check if any bucket versions from 0 to minExperimentBucketVersion are blocked.
    if (minExperimentBucketVersion > 0) {
      for (int version = 0; version <= minExperimentBucketVersion; version++) {
        final blockedKey = getStickyBucketExperimentKey(experimentKey, version);
        if (assignments.containsKey(blockedKey)) {
          // A blocked version was found.
          return StickyBucketResult(variation: -1, versionIsBlocked: true);
        }
      }
    }

    final variationKey = assignments[assignmentKey];

    if (variationKey == null) {
      // no assignment found
      return StickyBucketResult(variation: -1);
    }

    final variation = meta.indexWhere((m) => m.key == variationKey);

    if (variation < 0) {
      // invalid assignment, treat as "no assignment found"
      return StickyBucketResult(variation: -1);
    }

    return StickyBucketResult(variation: variation);
  }

  static String getStickyBucketExperimentKey(String experimentKey, int experimentBucketVersion) {
    return '${experimentKey}__$experimentBucketVersion';
  }

  static StickyBucketDocumentChange generateStickyBucketAssignmentDoc({
    required GBContext context,
    required String attributeName,
    required String attributeValue,
    required Map<String, String> newAssignments,
  }) {
    // Generate the key using attribute name and value.
    final key = '$attributeName||$attributeValue';

    // Get the existing assignments from the context.
    final existingAssignments = context.stickyBucketAssignmentDocs?[key]?.assignments ?? {};

    // Merge existing assignments with the new assignments.
    final mergedAssignments = {...existingAssignments, ...newAssignments};

    // Check if the merged assignments are different from the existing assignments.
    final hasChanged = mergedAssignments.toString() != existingAssignments.toString();

    // Create a new document with the merged assignments.
    final doc = StickyAssignmentsDocument(
      attributeName: attributeName,
      attributeValue: attributeValue,
      assignments: mergedAssignments,
    );

    // Return the key, document, and whether the document has changed.
    return StickyBucketDocumentChange(key, doc, hasChanged);
  }
}

extension RoundToExtension on num {
  num roundTo({int numFractionDigits = 0}) {
    final fractionDigits = numFractionDigits.clamp(0, 20); // Ensure fractionDigits is within range
    final stringValue = toStringAsFixed(fractionDigits);
    return num.parse(stringValue); // Convert back to num
  }
}
