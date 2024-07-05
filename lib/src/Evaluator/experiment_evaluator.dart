import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Evaluator/experiment_helper.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_variation_meta.dart';

class ExperimentEvaluator {
  Map<String, dynamic> attributeOverrides;

  ExperimentEvaluator({required this.attributeOverrides});

  // Takes Context and Experiment and returns ExperimentResult
  GBExperimentResult evaluateExperiment(GBContext context, GBExperiment experiment, {String? featureId}) {
    // Check if experiment.variations has fewer than 2 variations
    if (experiment.variations.length < 2 || context.enabled != true) {
      // Return an ExperimentResult indicating not in experiment and variationId 0
      return _getExperimentResult(
        featureId: featureId,
        experiment: experiment,
        context: context,
        variationIndex: -1,
        hashUsed: false,
      );
    }

    if (context.forcedVariation != null && context.forcedVariation!.containsKey(experiment.key)) {
      // Retrieve the forced variation for the experiment key
      if (context.forcedVariation != null && context.forcedVariation?[experiment.key] != null) {
        int forcedVariationIndex = int.parse(context.forcedVariation![experiment.key].toString());

        // Return the experiment result using the forced variation index and indicating that no hash was used
        return _getExperimentResult(
          featureId: featureId,
          context: context,
          experiment: experiment,
          variationIndex: forcedVariationIndex,
          hashUsed: false,
        );
      }
    }

    if (!experiment.active) {
      return _getExperimentResult(
        featureId: featureId,
        context: context,
        experiment: experiment,
        variationIndex: -1,
        hashUsed: false,
      );
    }

    final hashAttributeAndValue = GBUtils.getHashAttribute(
      context: context,
      attr: experiment.hashAttribute,
      fallback: (context.stickyBucketService != null && (experiment.disableStickyBucketing != true))
          ? experiment.fallbackAttribute
          : null,
      attributeOverrides: attributeOverrides,
    );

    final hashAttribute = hashAttributeAndValue[0];
    final hashValue = hashAttributeAndValue[1];

    if (hashValue.isEmpty || hashValue == "null") {
      log('Skip because missing hashAttribute');
      return _getExperimentResult(
        featureId: featureId,
        context: context,
        experiment: experiment,
        variationIndex: -1,
        hashUsed: false,
      );
    }

    int assigned = -1;
    bool foundStickyBucket = false;
    bool stickyBucketVersionIsBlocked = false;

    if (context.stickyBucketService != null && (experiment.disableStickyBucketing != true)) {
      final stickyBucketResult = GBUtils.getStickyBucketVariation(
        context: context,
        experimentKey: experiment.key,
        experimentBucketVersion: experiment.bucketVersion ?? 0,
        minExperimentBucketVersion: experiment.minBucketVersion ?? 0,
        meta: experiment.meta ?? [],
        expHashAttribute: experiment.hashAttribute ?? "id",
        expFallBackAttribute: experiment.fallbackAttribute!,
        attributeOverrides: attributeOverrides,
      );
      foundStickyBucket = stickyBucketResult.variation >= 0;
      assigned = stickyBucketResult.variation;
      stickyBucketVersionIsBlocked = stickyBucketResult.versionIsBlocked ?? false;
    }

    if (!foundStickyBucket) {
      if (experiment.filters != null) {
        if (GBUtils.isFilteredOut(experiment.filters!, context, attributeOverrides)) {
          log('Skip because of filters');
          return _getExperimentResult(
            featureId: featureId,
            context: context,
            experiment: experiment,
            variationIndex: -1,
            hashUsed: false,
          );
        }
      } else if (experiment.namespace != null) {
        final namespace = GBUtils.getGBNameSpace(experiment.namespace ?? []);
        if (namespace != null) {
          if (!GBUtils.inNamespace(hashValue, namespace)) {
            log('Skip because of namespace');
            return _getExperimentResult(
              featureId: featureId,
              context: context,
              experiment: experiment,
              variationIndex: -1,
              hashUsed: false,
            );
          }
        }
      }

      if (experiment.condition != null &&
          !GBConditionEvaluator().isEvalCondition(context.attributes!, experiment.condition!, context.savedGroups)) {
        return _getExperimentResult(
          featureId: featureId,
          context: context,
          experiment: experiment,
          variationIndex: -1,
          hashUsed: false,
        );
      }

      if (experiment.parentConditions != null) {
        for (final parentCondition in experiment.parentConditions!) {
          final parentResult = FeatureEvaluator(
            context: context,
            featureKey: parentCondition.id,
            attributeOverrides: parentCondition.condition,
          ).evaluateFeature();

          if (parentResult.source?.name == GBFeatureSource.cyclicPrerequisite.name) {
            return _getExperimentResult(
              featureId: featureId,
              context: context,
              experiment: experiment,
              variationIndex: -1,
              hashUsed: false,
            );
          }

          final evalObj = {'value': parentResult.value};
          final evalCondition = GBConditionEvaluator().isEvalCondition(
            evalObj,
            parentCondition.condition,
            context.savedGroups,
          );

          if (!evalCondition) {
            log("Feature blocked by prerequisite");
            return _getExperimentResult(
              featureId: featureId,
              context: context,
              experiment: experiment,
              variationIndex: -1,
              hashUsed: false,
            );
          }
        }
      }
    }

    final hash = GBUtils.hash(
      seed: experiment.seed ?? experiment.key,
      value: hashValue,
      version: experiment.hashVersion?.toInt() ?? 1,
    );

    if (hash == null) {
      log('Skip because of invalid hash version');
      return _getExperimentResult(
        featureId: featureId,
        context: context,
        experiment: experiment,
        variationIndex: -1,
        hashUsed: false,
      );
    }

    if (!foundStickyBucket) {
      final ranges = experiment.ranges ??
          GBUtils.getBucketRanges(
            experiment.variations.length,
            experiment.coverage ?? 1.0,
            experiment.weights,
          );
      assigned = const GBUtils().chooseVariation(hash, ranges);
    }

    if (stickyBucketVersionIsBlocked) {
      log('Skip because sticky bucket version is blocked');
      return _getExperimentResult(
        featureId: featureId,
        context: context,
        experiment: experiment,
        variationIndex: -1,
        hashUsed: false,
        bucket: null,
        stickyBucketUsed: true,
      );
    }

    if (assigned < 0) {
      log('Skip because of coverage');
      return _getExperimentResult(
        featureId: featureId,
        context: context,
        experiment: experiment,
        variationIndex: -1,
        hashUsed: false,
      );
    }

    if (experiment.force != null) {
      return _getExperimentResult(
        featureId: featureId,
        context: context,
        experiment: experiment,
        variationIndex: experiment.force!,
        hashUsed: false,
      );
    }

    if (context.qaMode) {
      return _getExperimentResult(
        featureId: featureId,
        context: context,
        experiment: experiment,
        variationIndex: -1,
        hashUsed: false,
      );
    }

    final result = _getExperimentResult(
      featureId: featureId,
      context: context,
      experiment: experiment,
      variationIndex: assigned,
      hashUsed: true,
      bucket: hash,
      stickyBucketUsed: foundStickyBucket,
    );

    if (context.stickyBucketService != null && (experiment.disableStickyBucketing != true)) {
      final stickyBucketDoc = GBUtils.generateStickyBucketAssignmentDoc(
        context: context,
        attributeName: hashAttribute,
        attributeValue: hashValue,
        newAssignments: {
          GBUtils.getStickyBucketExperimentKey(experiment.key, experiment.bucketVersion ?? 0): result.key
        },
      );

      if (stickyBucketDoc.hasChanged) {
        context.stickyBucketAssignmentDocs ??= {};
        context.stickyBucketAssignmentDocs![stickyBucketDoc.key] = stickyBucketDoc.doc;
        context.stickyBucketService?.saveAssignments(stickyBucketDoc.doc);
      }
    }

    if (!ExperimentHelper.shared.isTracked(experiment, result)) {
      context.trackingCallBack!(experiment, result);
    }

    return result;
  }

  GBExperimentResult _getExperimentResult({
    required GBContext context,
    required GBExperiment experiment,
    int variationIndex = 0,
    required bool hashUsed,
    String? featureId,
    double? bucket,
    bool? stickyBucketUsed,
  }) {
    bool inExperiment = true;

    int targetVariationIndex = variationIndex;

    // Check whether variationIndex lies within bounds of variations size
    if (targetVariationIndex < 0 || targetVariationIndex >= experiment.variations.length) {
      // Set to 0
      targetVariationIndex = 0;
      inExperiment = false;
    }
    final hashResult = GBUtils.getHashAttribute(
      context: context,
      attr: experiment.hashAttribute,
      fallback: (context.stickyBucketService != null && (experiment.disableStickyBucketing != true))
          ? experiment.fallbackAttribute
          : null,
      attributeOverrides: attributeOverrides,
    );

    String hashAttribute = hashResult[0];
    dynamic hashValue = hashResult[1];

    // Retrieve experiment metadata
    List<GBVariationMeta> experimentMeta = experiment.meta ?? [];
    GBVariationMeta? meta =
        (experimentMeta.length > targetVariationIndex) ? experimentMeta[targetVariationIndex] : null;

    return GBExperimentResult(
      inExperiment: inExperiment,
      variationID: targetVariationIndex,
      value: (experiment.variations.length > targetVariationIndex) ? experiment.variations[targetVariationIndex] : {},
      hashAttribute: hashAttribute,
      hashValue: hashValue,
      key: meta?.key ?? '$targetVariationIndex',
      featureId: featureId,
      hashUsed: hashUsed,
      stickyBucketUsed: stickyBucketUsed ?? false,
      name: meta?.name,
      bucket: bucket,
      passthrough: meta?.passthrough,
    );
  }
}

class StickyBucketDocumentChange {
  final String key;
  final StickyAssignmentsDocument doc;
  final bool hasChanged;

  StickyBucketDocumentChange(this.key, this.doc, this.hasChanged);
}

class StickyBucketResult {
  final int variation;
  final bool? versionIsBlocked;

  StickyBucketResult({required this.variation, this.versionIsBlocked});
}
