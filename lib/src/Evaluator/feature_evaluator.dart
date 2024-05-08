import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Evaluator/experiment_helper.dart';

/// Feature Evaluator Class
/// Takes Context and Feature Key
/// Returns Calculated Feature Result against that key

class FeatureEvaluator {
  GBContext context;
  FeatureEvalContext? evalContext;
  String featureKey;
  Map<String, dynamic> attributeOverrides;

  FeatureEvaluator({
    required this.context,
    required this.featureKey,
    required this.attributeOverrides,
    FeatureEvalContext? evalContext,
  }) : evalContext =
            evalContext ?? FeatureEvalContext(evaluatedFeatures: <String>{});

  /// Takes context and feature key and returns the calculated feature result against that key.
  GBFeatureResult evaluateFeature() {
    // Check if the feature has been evaluated already and return early if it has
    if (evalContext?.evaluatedFeatures.contains(featureKey) ?? false) {
      return prepareResult(
        value: null,
        source: GBFeatureSource.cyclicPrerequisite,
      );
    }

    evalContext?.evaluatedFeatures.add(featureKey);
    evalContext?.id = featureKey;

    // Check if the targetFeature is available in context.features using the featureKey
    GBFeature? targetFeature = context.features[featureKey];

    // If the targetFeature is not found, return a result with null value and unknown feature source
    if (targetFeature == null) {
      return prepareResult(
        value: null,
        source: GBFeatureSource.unknownFeature,
      );
    }

    if (targetFeature.rules != null && targetFeature.rules!.isNotEmpty) {
      // Iterate through each rule in the target feature's rules
      ruleLoop:
      for (var rule in targetFeature.rules!) {
        // Check if the rule has parent conditions
        if (rule.parentConditions != null) {
          // Iterate through each parent condition
          for (var parentCondition in rule.parentConditions!) {
            // Evaluate the parent condition using a new FeatureEvaluator
            var parentEvaluator = FeatureEvaluator(
              context: context,
              featureKey: parentCondition.id,
              attributeOverrides: attributeOverrides,
              evalContext: evalContext,
            );
            GBFeatureResult parentResult = parentEvaluator.evaluateFeature();

            // Check if the source of the parent result is cyclic prerequisite
            if (parentResult.source == GBFeatureSource.cyclicPrerequisite) {
              return prepareResult(
                value: null, // Corresponds to .null in Swift
                source: GBFeatureSource.cyclicPrerequisite,
              );
            }

            // Create a map with the parent result value for evaluation
            var evalObj = {'value': parentResult.value};

            // Evaluate the condition with the attributes and condition object
            bool evalCondition = GBConditionEvaluator().evaluateCondition(
              evalObj,
              parentCondition.condition,
            );

            // If the evaluation condition is false
            if (!evalCondition) {
              // Check if there is a gate in the parent condition
              if (parentCondition.gate != null) {
                log('Feature blocked by prerequisite');
                return prepareResult(
                  value: null, // Corresponds to .null in Swift
                  source: GBFeatureSource.prerequisite,
                );
              }

              // Non-blocking prerequisite evaluation failed; continue to the next rule
              continue ruleLoop;
            }
          }
        }
        if (rule.filters != null) {
          if (GBUtils.isFilteredOut(
              rule.filters!, context, attributeOverrides)) {
            log('Skip rule because of filters');
            continue; // Skip to the next rule
          }
        }

        // Check if rule.force is set
        if (rule.force != null) {
          if (rule.condition != null &&
              !GBConditionEvaluator().evaluateCondition(
                getAttributes(),
                rule.condition!,
              )) {
            log('Skip rule because of condition');
            continue; // Skip to the next rule
          }

          // Check if the user is included in the rollout
          bool isUserIncluded = GBUtils.isIncludedInRollout(
            attributeOverrides,
            rule.seed ?? featureKey,
            rule.hashAttribute,
            (context.stickyBucketService != null &&
                    (rule.disableStickyBucketing != true))
                ? rule.fallbackAttribute
                : null,
            rule.range,
            rule.coverage,
            rule.hashVersion,
            context,
          );

          if (!isUserIncluded) {
            log('Skip rule because user not included in rollout');
            continue; // Skip to the next rule
          }

          // Handle tracks if present
          if (rule.tracks != null) {
            for (var track in rule.tracks!) {
              if (!ExperimentHelper.shared
                  .isTracked(track.experiment, track.experimentResult)) {
                context.trackingCallBack!(
                    track.experiment, track.experimentResult);
              }
            }
          }
          if (rule.range == null) {
            if (rule.coverage != null) {
              // Get the key for hash attribute (defaults to 'id' if not specified)
              String key = rule.hashAttribute ?? Constant.idAttribute;

              // Get the user hash value from context attributes based on the key
              String? attributeValue = context.attributes?[key].toString();

              // If attributeValue is empty or null, skip the rule
              if (attributeValue == null || attributeValue.isEmpty) {
                continue; // Skip the current rule
              }

              // Compute the hash using the Fowler-Noll-Vo algorithm (fnv32-1a)
              double hashFNV = GBUtils.hash(
                      seed: featureKey, value: attributeValue, version: 1) ??
                  0.0;

              // If the computed hash value is greater than rule.coverage, skip the rule
              if (hashFNV > rule.coverage!) {
                continue ruleLoop; // Skip the current rule
              }
            }
          }

          return prepareResult(
              value: rule.force!, source: GBFeatureSource.force);
        } else {
          if (rule.variations == null) {
            // If not, skip this rule
            continue;
          } else {
            // Convert the rule to an Experiment object
            GBExperiment exp = GBExperiment(
              key: rule.key ?? featureKey,
              variations: rule.variations!,
              namespace: rule.namespace,
              hashAttribute: rule.hashAttribute,
              fallbackAttribute: rule.fallbackAttribute,
              hashVersion: rule.hashVersion?.toDouble(),
              disableStickyBucketing: rule.disableStickyBucketing,
              bucketVersion: rule.bucketVersion,
              minBucketVersion: rule.minBucketVersion,
              weights: rule.weights,
              coverage: rule.coverage,
              condition: rule.condition,
              ranges: rule.ranges,
              meta: rule.meta,
              filters: rule.filters,
              seed: rule.seed,
              name: rule.name,
              phase: rule.phase,
            );
            GBExperimentResult result =
                ExperimentEvaluator(attributeOverrides: attributeOverrides)
                    .evaluateExperiment(context, exp, featureId: featureKey);

            // Check if the result is in the experiment and not a passthrough
            if (result.inExperiment && !(result.passthrough ?? false)) {
              // Return the result value and source if the result is successful
              return prepareResult(
                value: result.value,
                source: GBFeatureSource.experiment,
                experiment: exp,
                result: result,
              );
            }
          }
        }
      }
    }
    return prepareResult(
        value: targetFeature.defaultValue,
        source: GBFeatureSource.defaultValue);
  }

  GBFeatureResult prepareResult({
    dynamic value,
    required GBFeatureSource source,
    GBExperiment? experiment,
    GBExperimentResult? result,
  }) {
    var isFalse = false;

    if (value == null) {
      isFalse = true;
    } else if (value.toString() == 'false' ||
        value.toString() == '0' ||
        (value.toString().isEmpty && value is! Map && value is! List)) {
      isFalse = true;
    }
    return GBFeatureResult(
      value: value,
      on: !isFalse,
      off: isFalse,
      source: source,
      experiment: experiment,
      experimentResult: result,
    );
  }

  Map<String, dynamic> getAttributes() {
    try {
      // Merge context.attributes with attributeOverrides
      Map<String, dynamic> mergedAttributes = {...?context.attributes};

      // Iterate over attributeOverrides and merge them into mergedAttributes
      attributeOverrides.forEach((key, value) {
        mergedAttributes[key] = value;
      });

      return mergedAttributes;
    } catch (e) {
      // If any exception occurs during the merge, return an empty map (equivalent to an empty JSON object)
      return {};
    }
  }
}

class FeatureEvalContext {
  String? id;
  Set<String> evaluatedFeatures;

  // Constructor
  FeatureEvalContext({
    this.id,
    Set<String>? evaluatedFeatures,
  }) : evaluatedFeatures = evaluatedFeatures ?? <String>{};
}
