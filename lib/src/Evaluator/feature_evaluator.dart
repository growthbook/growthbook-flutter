import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Evaluator/experiment_helper.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';

/// Feature Evaluator Class
/// Takes Context and Feature Key
/// Returns Calculated Feature Result against that key

class FeatureEvaluator {
  /// Takes context and feature key and returns the calculated feature result against that key.
  GBFeatureResult evaluateFeature(EvaluationContext context, String featureKey) {
    /// This callback serves for listening for feature usage events
    final onFeatureUsageCallbackWithUser = context.options.featureUsageCallbackWithUser;

    // Check if the feature has been evaluated already and return early if it has

    if (context.stackContext.evaluatedFeatures.contains(featureKey)) {
      final featureResultWhenCircularDependencyDetected = prepareResult(
        value: null,
        source: GBFeatureSource.cyclicPrerequisite,
      );

      onFeatureUsageCallbackWithUser?.call(featureKey, featureResultWhenCircularDependencyDetected);

      return featureResultWhenCircularDependencyDetected;
    }

    context.stackContext.evaluatedFeatures.add(featureKey);
    context.stackContext.id = featureKey;

    // Check if the targetFeature is available in context.features using the featureKey
    GBFeature? targetFeature = context.globalContext.features?[featureKey];

    // If the targetFeature is not found, return a result with null value and unknown feature source
    if (targetFeature == null) {
      final emptyFeatureResult = prepareResult(
        value: null,
        source: GBFeatureSource.unknownFeature,
      );

      onFeatureUsageCallbackWithUser?.call(featureKey, emptyFeatureResult);
      return emptyFeatureResult;
    }

    if (targetFeature.rules != null && targetFeature.rules!.isNotEmpty) {
      final evaluatedFeatures = context.stackContext.evaluatedFeatures.toSet();
      // Iterate through each rule in the target feature's rules
      ruleLoop:
      for (var rule in targetFeature.rules!) {
        // Check if the rule has parent conditions
        if (rule.parentConditions != null) {
          // Iterate through each parent condition
          for (var parentCondition in rule.parentConditions!) {
            context.stackContext.evaluatedFeatures = evaluatedFeatures.toSet();
            // Evaluate the parent condition using a new FeatureEvaluator
            GBFeatureResult parentResult = FeatureEvaluator().evaluateFeature(context, parentCondition.id);

            // Check if the source of the parent result is cyclic prerequisite
            if (parentResult.source == GBFeatureSource.cyclicPrerequisite) {
              final featureResultWhenCircularDependencyDetected = prepareResult(
                value: null, // Corresponds to .null in Swift
                source: GBFeatureSource.cyclicPrerequisite,
              );

              onFeatureUsageCallbackWithUser?.call(featureKey, featureResultWhenCircularDependencyDetected);

              return featureResultWhenCircularDependencyDetected;
            }

            // Create a map with the parent result value for evaluation
            var evalObj = {'value': parentResult.value};

            // Evaluate the condition with the attributes and condition object
            bool evalCondition = GBConditionEvaluator().isEvalCondition(
              evalObj,
              parentCondition.condition,
              context.globalContext.savedGroups,
            );

            // If the evaluation condition is false
            if (!evalCondition) {
              // Check if there is a gate in the parent condition
              if (parentCondition.gate != null) {
                logger.w('Feature blocked by prerequisite');
                final featureResultWhenBlockedByPrerequisite = prepareResult(
                  value: null, // Corresponds to .null in Swift
                  source: GBFeatureSource.prerequisite,
                );

                onFeatureUsageCallbackWithUser?.call(featureKey, featureResultWhenBlockedByPrerequisite);

                return featureResultWhenBlockedByPrerequisite;
              }

              // Non-blocking prerequisite evaluation failed; continue to the next rule
              continue ruleLoop;
            }
          }
        }
        if (rule.filters != null) {
          if (GBUtils.isFilteredOut(rule.filters!, context.userContext.attributes ?? {})) {
            logger.w('Skip rule because of filters');
            continue; // Skip to the next rule
          }
        }

        // Check if rule.force is set
        if (rule.force != null) {
          if (rule.condition != null &&
              !GBConditionEvaluator().isEvalCondition(
                context.userContext.attributes ?? {},
                rule.condition!,
                context.globalContext.savedGroups,
              )) {
            logger.w('Skip rule because of condition');
            continue; // Skip to the next rule
          }

          // Check if the user is included in the rollout
          bool isUserIncluded = GBUtils.isIncludedInRollout(
            context.userContext.attributes ?? {},
            rule.seed ?? featureKey,
            rule.hashAttribute,
            (context.options.stickyBucketService != null && (rule.disableStickyBucketing != true))
                ? rule.fallbackAttribute
                : null,
            rule.range,
            rule.coverage,
            rule.hashVersion,
          );

          if (!isUserIncluded) {
            logger.w('Skip rule because user not included in rollout');
            continue; // Skip to the next rule
          }

          // Handle tracks if present
          if (rule.tracks != null) {
            for (var track in rule.tracks!) {
              if (track.featureResult?.experiment != null && track.featureResult?.experimentResult != null) {
                if (track.featureResult != null) {
                  var experiment = track.featureResult!.experiment!;
                  var result = track.featureResult!.experimentResult!;
                  if (!ExperimentHelper.shared.isTracked(experiment, result)) {
                    context.options
                        .trackingCallBackWithUser!(GBTrackData(experiment: experiment, experimentResult: result));
                  }
                }
              }
            }
          }
          if (rule.range == null) {
            if (rule.coverage != null) {
              // Get the key for hash attribute (defaults to 'id' if not specified)
              String key = rule.hashAttribute ?? Constant.idAttribute;

              // Get the user hash value from context attributes based on the key
              String? attributeValue = context.userContext.attributes?[key].toString();

              // If attributeValue is empty or null, skip the rule
              if (attributeValue == null || attributeValue.isEmpty) {
                continue; // Skip the current rule
              }

              // Compute the hash using the Fowler-Noll-Vo algorithm (fnv32-1a)
              double hashFNV = GBUtils.hash(seed: featureKey, value: attributeValue, version: 1) ?? 0.0;

              // If the computed hash value is greater than rule.coverage, skip the rule
              if (hashFNV > rule.coverage!) {
                continue ruleLoop; // Skip the current rule
              }
            }
          }
          final forcedFeatureResult = prepareResult(value: rule.force!, source: GBFeatureSource.force, ruleId: rule.id);
          onFeatureUsageCallbackWithUser?.call(featureKey, forcedFeatureResult);
          return forcedFeatureResult;
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
            GBExperimentResult result = ExperimentEvaluator().evaluateExperiment(context, exp, featureId: featureKey);

            // Check if the result is in the experiment and not a passthrough
            if (result.inExperiment && !(result.passthrough ?? false)) {
              // Return the result value and source if the result is successful
              final experimentFeatureResult = prepareResult(
                value: result.value,
                source: GBFeatureSource.experiment,
                experiment: exp,
                result: result,
                ruleId: rule.id
              );
              onFeatureUsageCallbackWithUser?.call(featureKey, experimentFeatureResult);
              return experimentFeatureResult;
            }
          }
        }
      }
    }
    final defaultFeatureResult = prepareResult(value: targetFeature.defaultValue, source: GBFeatureSource.defaultValue);
    onFeatureUsageCallbackWithUser?.call(featureKey, defaultFeatureResult);
    return defaultFeatureResult;
  }

  /// This is a helper method to create a FeatureResult object.
  /// Besides the passed-in arguments, there are two derived values -
  /// on and off, which are just the value cast to booleans.
  GBFeatureResult prepareResult({
    dynamic value,
    required GBFeatureSource source,
    GBExperiment? experiment,
    GBExperimentResult? result,
    String? ruleId = ""
  }) {
    var isFalse = value == null ||
        value.toString() == 'false' ||
        value.toString() == '0' ||
        (value.toString().isEmpty && value is! Map && value is! List);
    return GBFeatureResult(
      value: value,
      on: !isFalse,
      off: isFalse,
      source: source,
      experiment: experiment,
      experimentResult: result,
      ruleId: ruleId
    );
  }

  Map<String, dynamic> getAttributes(GBContext context) {
    try {
      // Merge context.attributes with attributeOverrides
      Map<String, dynamic> mergedAttributes = {...?context.attributes};

      // Iterate over attributeOverrides and merge them into mergedAttributes
      context.attributes?.forEach((key, value) {
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

  FeatureEvalContext({
    this.id,
    Set<String>? evaluatedFeatures,
  }) : evaluatedFeatures = evaluatedFeatures ?? <String>{};
}
