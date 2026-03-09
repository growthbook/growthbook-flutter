import 'dart:collection';

import 'package:growthbook_sdk_flutter/src/Evaluator/experiment_evaluator.dart';
import 'package:growthbook_sdk_flutter/src/Model/context.dart';
import 'package:growthbook_sdk_flutter/src/Model/features_model.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/global_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/options.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/user_context.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_filter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_variation_meta.dart';
import 'package:growthbook_sdk_flutter/src/Utils/utils.dart';

/// Fowler-Noll-Vo hash - 32 bit
class FNV {
  // Constants for FNV-1a 32-bit hash
  final int init32 = 0x811c9dc5;
  final int prime32 = 0x01000193;

  /// Fowler-Noll-Vo hash - 32 bit
  /// Returns an integer representing the hash.
  int fnv1a32(String str) {
    int hval = init32;
    for (int i = 0; i < str.length; i++) {
      hval ^= str.codeUnitAt(i);

      hval +=
          (hval << 1) + (hval << 4) + (hval << 7) + (hval << 8) + (hval << 24);

      hval &= 0xFFFFFFFF;
      hval = hval.toSigned(32);
    }
    return hval.toUnsigned(32);
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
    final hashValue =
        hash(value: "${userId}__", seed: namespace.item1, version: 1);
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
  static List<GBBucketRange> getBucketRanges(
      int numVariations, double coverage, List<double>? weights) {
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
    double weightsSum =
        targetWeights.fold<double>(0, (prev, element) => prev + element);
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
        return GBNameSpace(title, double.parse(start.toString()),
            double.parse(end.toString()));
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
    Map<String, dynamic> attributes,
  ) {
    return filters.any((filter) {
      final hashAttributeAndValue = GBUtils.getHashAttribute(
        attr: filter.attribute,
        attributes: attributes,
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

  static bool isIncludedInRollout(
      Map<String, dynamic> attributes,
      String? seed,
      String? hashAttribute,
      String? fallbackAttribute,
      GBBucketRange? range,
      double? coverage,
      int? hashVersion) {
    // If both range and coverage are null, return true
    if (range == null && coverage == null) return true;

    if (range == null && coverage == 0) return false;

    // Get the hash attribute and its value
    var hashAttrResult = getHashAttribute(
        attr: hashAttribute,
        fallback: fallbackAttribute,
        attributes: attributes);
    String? hashValue = hashAttrResult[1];

    if (hashValue.isEmpty || hashValue == "null") {
      return false;
    }

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

  /// Returns a tuple of two elements: the attribute itself and its hash value.
  static List<String> getHashAttribute({
    String? attr,
    String? fallback,
    required Map<String, dynamic> attributes,
    Map<String, dynamic>? attributeOverrides,
  }) {
    String hashAttribute = attr ?? 'id';
    String hashValue = '';

    if (attributeOverrides != null &&
        attributeOverrides[hashAttribute] != null) {
      hashValue = attributeOverrides[hashAttribute].toString();
    } else if (attributes[hashAttribute] != null) {
      hashValue = attributes[hashAttribute].toString();
    }

    // If no match, try fallback
    if (hashValue.isEmpty && fallback != null) {
      if (attributeOverrides != null && attributeOverrides[fallback] != null) {
        hashValue = attributeOverrides[fallback].toString();
      } else if (attributes[fallback] != null) {
        hashValue = attributes[fallback].toString();
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
    required EvaluationContext context,
    required String? expHashAttribute,
    required String? expFallBackAttribute,
  }) {
    final assignments = <String, String>{};

    Map<StickyAttributeKey, StickyAssignmentsDocument>?
        stickyBucketAssignmentDocs =
        <StickyAttributeKey, StickyAssignmentsDocument>{};

    // Check if stickyBucketAssignmentDocs is null
    if (context.userContext.stickyBucketAssignmentDocs == null) {
      return assignments;
    } else {
      stickyBucketAssignmentDocs =
          context.userContext.stickyBucketAssignmentDocs;
    }

    // Retrieve hashAttributeAndValue and hashKey
    final hashAttributeAndValue = getHashAttribute(
      attr: expHashAttribute,
      fallback: null,
      attributes: context.userContext.attributes!,
    );

    final hashKey = '${hashAttributeAndValue[0]}||${hashAttributeAndValue[1]}';

    // Retrieve fallbackAttributeAndValue and fallbackKey
    final fallbackAttributeAndValue = getHashAttribute(
      attr: expFallBackAttribute,
      fallback: null,
      attributes: context.userContext.attributes!,
    );

    String? fallbackKey;

    if (fallbackAttributeAndValue[1].isEmpty) {
      fallbackKey = null;
    } else {
      "${fallbackAttributeAndValue[0]}||${fallbackAttributeAndValue[1]}";
    }

    String? leftOperand = context
        .userContext
        .stickyBucketAssignmentDocs?[
            "$expFallBackAttribute||${context.userContext.attributes![expFallBackAttribute]}"]
        ?.attributeValue;

    if (leftOperand != context.userContext.attributes?[expFallBackAttribute]) {
      context.userContext.stickyBucketAssignmentDocs = {};
    }

    // Add assignments from stickyBucketAssignmentDocs
    context.userContext.stickyBucketAssignmentDocs?.forEach((key, doc) {
      assignments.addAll(doc.assignments);
    });

    // Add assignments from fallbackKey if not null
    if (fallbackKey != null &&
        stickyBucketAssignmentDocs?[fallbackKey] != null) {
      assignments
          .addAll(stickyBucketAssignmentDocs?[fallbackKey]?.assignments ?? {});
    }

    // Add assignments from hashKey if not null
    if (stickyBucketAssignmentDocs?[hashKey] != null) {
      assignments
          .addAll(stickyBucketAssignmentDocs![hashKey]?.assignments ?? {});
    }

    return assignments;
  }

  static Future<void> refreshStickyBuckets(
    GBContext context,
    FeaturedDataModel? data,
    Map<String, dynamic> attributes,
  ) async {
    if (context.stickyBucketService == null) {
      return;
    }
    if (context.stickyBucketService == null) return;
    var allAttributes = getStickyBucketAttributes(context, data, attributes);
    context.stickyBucketAssignmentDocs =
        await context.stickyBucketService?.getAllAssignments(allAttributes);
  }

  static Map<String, String> getStickyBucketAttributes(
    GBContext context,
    FeaturedDataModel? data,
    Map<String, dynamic> attributeOverrides,
  ) {
    var attributes = <String, String>{};
    context.stickyBucketIdentifierAttributes = context
            .stickyBucketIdentifierAttributes ??
        deriveStickyBucketIdentifierAttributes(context: context, data: data);

    if (context.stickyBucketIdentifierAttributes != null) {
      for (var attr in context.stickyBucketIdentifierAttributes!) {
        var hashValue = GBUtils.getHashAttribute(
            attributes: attributes,
            attr: attr,
            attributeOverrides: attributeOverrides);
        attributes[attr] = hashValue[1];
      }
    }
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
    required EvaluationContext context,
    required String experimentKey,
    required int experimentBucketVersion,
    required int minExperimentBucketVersion,
    required List<GBVariationMeta> meta,
    required String expHashAttribute,
    required String? expFallBackAttribute,
  }) {
    // Get the assignment key for the given experiment key and version.
    final assignmentKey =
        getStickyBucketExperimentKey(experimentKey, experimentBucketVersion);
    // Fetch all sticky bucket assignments from the context.
    final assignments = getStickyBucketAssignments(
      context: context,
      expHashAttribute: expHashAttribute,
      expFallBackAttribute: expFallBackAttribute,
    );

    // Check if any bucket versions from 0 to minExperimentBucketVersion are blocked.
    if (minExperimentBucketVersion > 0) {
      for (int version = 0; version < minExperimentBucketVersion; version++) {
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

  static String getStickyBucketExperimentKey(
      String experimentKey, int experimentBucketVersion) {
    return '${experimentKey}__$experimentBucketVersion';
  }

  static StickyBucketDocumentChange generateStickyBucketAssignmentDoc({
    required EvaluationContext context,
    required String attributeName,
    required String attributeValue,
    required Map<String, String> newAssignments,
  }) {
    // Generate the key using attribute name and value.
    final key = '$attributeName||$attributeValue';

    // Get the existing assignments from the context.
    final existingAssignments =
        context.userContext.stickyBucketAssignmentDocs?[key]?.assignments ?? {};

    // Merge existing assignments with the new assignments.
    final mergedAssignments = {...existingAssignments, ...newAssignments};

    // Check if the merged assignments are different from the existing assignments.
    final hasChanged =
        mergedAssignments.toString() != existingAssignments.toString();

    // Create a new document with the merged assignments.
    final doc = StickyAssignmentsDocument(
      attributeName: attributeName,
      attributeValue: attributeValue,
      assignments: mergedAssignments,
    );

    // Return the key, document, and whether the document has changed.
    return StickyBucketDocumentChange(key, doc, hasChanged);
  }

  /// Checks if an experiment variation is being forced via a URL query string.
  /// This may not be applicable for all SDKs (e.g., mobile).
  ///
  /// For example, if the `id` is `"my-test"` and the URL is `http://localhost/?my-test=1`,
  /// this function would return `1`.
  ///
  /// Returns `null` if any of the following conditions are met:
  ///
  /// - There is no query string.
  /// - The `id` is not a key in the query string.
  /// - The variation is not an integer.
  /// - The variation is less than `0` or greater than or equal to `numberOfVariations`.
  ///
  ///
  /// - [id] The experiment identifier.
  /// - [urlString] The desired page URL as a string.
  /// - [numberOfVariations] The number of variations.
  ///
  /// Returns an `int` or `null`.
  static int? getQueryStringOverride(
      String id, String? urlString, int variations) {
    if (urlString == null || urlString.isEmpty) {
      return null;
    }

    try {
      Uri url = Uri.parse(urlString);
      return getQueryStringOverrideFromUrl(id, url, variations);
    } catch (e) {
      //print("Error parsing URL: $e");
      return null;
    }
  }

  /// Checks if an experiment variation is being forced via a URL query string.
  /// This may not be applicable for all SDKs (e.g., mobile).
  ///
  /// For example, if the `id` is `"my-test"` and the URL is `http://localhost/?my-test=1`,
  /// this function would return `1`.
  ///
  /// Returns `null` if any of the following conditions are met:
  ///
  /// - There is no query string.
  /// - The `id` is not a key in the query string.
  /// - The variation is not an integer.
  /// - The variation is less than `0` or greater than or equal to `numberOfVariations`.
  ///
  ///
  /// - [id] The experiment identifier.
  /// - [url] The desired page URL.
  /// - [numberOfVariations] The number of variations.
  ///
  /// Returns an `int` or `null`.
  static int? getQueryStringOverrideFromUrl(
      String id, Uri url, int numberOfVariations) {
    var queryString = url.query;
    var queryMap = parseQuery(queryString);

    String? possibleValue = queryMap[id];
    if (possibleValue == null) {
      return null;
    }

    try {
      int variationValue = int.parse(possibleValue);
      if (variationValue < 0 || variationValue >= numberOfVariations) {
        return null;
      }

      return variationValue;
    } catch (e) {
      //print("Error parsing integer: $e");
      return null;
    }
  }

  /// Parses a query string into a map of key/value pairs.
  ///
  /// - [queryString]: The string to parse (without the `?`).
  ///
  /// Returns a `Map<String, String>` containing the key/value pairs
  /// from the query string.
  static Map<String, String> parseQuery(String? query) {
    Map<String, String> map = HashMap();
    if (query == null || query.isEmpty) {
      return map;
    }
    var params = query.split("&");
    for (String param in params) {
      try {
        var keyValuePair = param.split("=");
        var name = Uri.decodeComponent(keyValuePair[0]);
        if (name.isEmpty) {
          continue;
        }
        String value = (keyValuePair.length > 1)
            ? Uri.decodeComponent(keyValuePair[1])
            : "";
        map[name] = value;
      } catch (e) {
        //print("Error decoding query parameter: $e");
      }
    }
    return map;
  }

  static EvaluationContext initializeEvalContext(
      GBContext gbContext, GBCacheRefreshHandler? refreshHandler) {
    var options = Options(
      enabled: gbContext.enabled,
      isQaMode: gbContext.qaMode,
      isCacheDisabled: false,
      hostUrl: gbContext.hostURL,
      clientKey: gbContext.apiKey,
      decryptionKey: gbContext.encryptionKey,
      stickyBucketIdentifierAttributes:
          gbContext.stickyBucketIdentifierAttributes,
      stickyBucketService: gbContext.stickyBucketService,
      trackingCallBackWithUser: gbContext.trackingCallBack!,
      featureUsageCallbackWithUser: gbContext.featureUsageCallback,
      featureRefreshCallback: refreshHandler,
      url: gbContext.url,
    );

    var globalContext = GlobalContext(
      features: gbContext.features,
      savedGroups: gbContext.savedGroups,
    );

    var userContext = UserContext(
      attributes: gbContext.attributes,
      stickyBucketAssignmentDocs: gbContext.stickyBucketAssignmentDocs,
      forcedVariationsMap: gbContext.forcedVariation,
    );

    var evalContext = EvaluationContext(
      globalContext: globalContext,
      userContext: userContext,
      stackContext: StackContext(),
      options: options,
    );

    return evalContext;
  }
}

extension RoundToExtension on num {
  num roundTo({int numFractionDigits = 0}) {
    final fractionDigits =
        numFractionDigits.clamp(0, 20); // Ensure fractionDigits is within range
    final stringValue = toStringAsFixed(fractionDigits);
    return num.parse(stringValue); // Convert back to num
  }
}
