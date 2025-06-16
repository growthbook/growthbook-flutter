import 'dart:convert';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';

import '../test_cases/test_case.dart';

/// Test helper class.
class GBTestHelper {
  static final testData = jsonDecode(gbTestCases);

  static List getStickyBucketingData() {
    return testData['stickyBucket'];
  }

  static List getEvalConditionData() {
    return testData['evalCondition'];
  }

  static List getRunExperimentData() {
    return testData['run'];
  }

  static List getFNVHashData() {
    return testData['hash'];
  }

  static List getFeatureData() {
    return testData['feature'];
  }

  static List? getDecryptData() {
    return testData?['decrypt']?.toList();
  }

  static List getBucketRangeData() {
    return testData['getBucketRange'];
  }

  static List getInNameSpaceData() {
    return testData['inNamespace'];
  }

  static List getChooseVariationData() {
    return testData['chooseVariation'];
  }

  static List getEqualWeightsData() {
    return testData['getEqualWeights'];
  }
}

class GBFeaturesTest {
  GBFeaturesTest({
    this.features,
    this.attributes,
    this.forcedVariations,
    this.stickyBucketAssignmentDocs,
  });

  final Map<String, GBFeature>? features;
  final Map<String, dynamic>? attributes;
  final dynamic forcedVariations;
  final Map<String, StickyAssignmentsDocument>? stickyBucketAssignmentDocs;

  factory GBFeaturesTest.fromMap(Map<String, dynamic> map) {
    return GBFeaturesTest(
      attributes: map['attributes'] as Map<String, dynamic>?,
      forcedVariations: map['forcedVariations'],
      features: (map['features'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, GBFeature.fromJson(value)),
      ),
      stickyBucketAssignmentDocs:
          (map['stickyBucketAssignmentDocs'] as Map<String, dynamic>?)?.map(
        (key, value) =>
            MapEntry(key, StickyAssignmentsDocument.fromJson(value)),
      ),
    );
  }
}

class GBFeatureResultTest {
  GBFeatureResultTest(
      {this.value,
      this.on = false,
      this.off = true,
      this.source,
      this.experiment,
      this.experimentResult,
      this.ruleId = ""});

  dynamic value;
  bool? on;
  bool? off;
  String? source;
  GBExperimentResultTest? experimentResult;
  GBExperiment? experiment;
  String? ruleId = "";

  factory GBFeatureResultTest.fromMap(Map<String, dynamic> map) =>
      GBFeatureResultTest(
        value: map['value'],
        on: map['on'],
        off: map['off'],
        source: map['source'],
        ruleId: map['ruleId'],
        experiment: map['experiment'] != null
            ? GBExperiment.fromJson(map['experiment'])
            : null,
        experimentResult: map['experimentResult'] != null
            ? GBExperimentResultTest.fromMap(
                map['experimentResult'],
              )
            : null,
      );
}

class GBContextTest {
  GBContextTest(
      {this.attributes,
      this.features = const <String, GBFeature>{},
      this.qaMode = false,
      this.enabled = true,
      this.forcedVariations,
      this.savedGroups,
      this.url});

  dynamic attributes;
  Map<String, GBFeature> features;
  bool qaMode;
  bool enabled;
  Map<String, dynamic>? forcedVariations;
  SavedGroupsValues? savedGroups;
  String? url;

  factory GBContextTest.fromMap(Map<String, dynamic> map) => GBContextTest(
      attributes: map['attributes'],
      features: (map['features'] as Map<String, dynamic>?)?.map((key, value) =>
              MapEntry(
                  key, GBFeature.fromJson(value as Map<String, dynamic>))) ??
          <String, GBFeature>{},
      qaMode: map['qaMode'] ?? false,
      enabled: map['enabled'] ?? true,
      forcedVariations: map['forcedVariations'],
      savedGroups: map['savedGroups'],
      url: map["url"] ?? "");
}

class GBExperimentResultTest {
  GBExperimentResultTest({
    this.inExperiment = false,
    this.variationId,
    this.value,
    this.hashAttribute,
    this.hashUsed,
    this.hashValue,
    this.key,
    this.name,
    this.bucket,
    this.passthrough,
    this.featureId,
    this.stickyBucketUsed,
  });

  /// Whether or not the user is part of the experiment
  bool? inExperiment;

  /// The array index of the assigned variation
  int? variationId;

  /// The array value of the assigned variation
  dynamic value;

  /// The user attribute used to assign a variation
  String? hashAttribute;

  /// If a hash was used to assign a variation
  bool? hashUsed;

  ///  The value of that attribute
  String? hashValue;

  /// The unique key for the assigned variation
  String? key;

  /// The human-readable name of the assigned variation
  String? name;

  /// The hash value used to assign a variation (float from `0` to `1`)
  double? bucket;

  /// Used for holdout groups
  bool? passthrough;

  /// The id of the feature (if any) that the experiment came from
  String? featureId;

  /// If sticky bucketing was used to assign a variation
  bool? stickyBucketUsed;

  factory GBExperimentResultTest.fromMap(Map<String, dynamic> map) =>
      GBExperimentResultTest(
        value: map['value'],
        inExperiment: map['inExperiment'],
        variationId: map['variationId'],
        hashAttribute: map['hashAttribute'],
        hashUsed: map['hashUsed'],
        hashValue: map['hashValue']?.toString(),
        key: map['key']?.toString(),
        name: map['name']?.toString(),
        bucket: map['bucket'],
        passthrough: map['passthrough'],
        featureId: map['featureId']?.toString(),
        stickyBucketUsed: map['stickyBucketUsed'],
      );
}
