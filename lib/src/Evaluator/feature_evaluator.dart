import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Evaluator/experiment_helper.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';

/// Feature Evaluator Class
/// Takes Context and Feature Key
/// Returns Calculated Feature Result against that key

class FeatureEvaluator {
  /// Takes context and feature key and returns the calculated feature result against that key.
  GBFeatureResult evaluateFeature(
      EvaluationContext context, String featureKey) {
    /// This callback serves for listening for feature usage events
    final onFeatureUsageCallbackWithUser =
        context.options.featureUsageCallbackWithUser;

    // Check if the feature has been evaluated already and return early if it has

    if (context.stackContext.evaluatedFeatures.contains(featureKey)) {
      final featureResultWhenCircularDependencyDetected = prepareResult(
        value: null,
        source: GBFeatureSource.cyclicPrerequisite,
      );

      onFeatureUsageCallbackWithUser?.call(
          featureKey, featureResultWhenCircularDependencyDetected);

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
            GBFeatureResult parentResult =
                FeatureEvaluator().evaluateFeature(context, parentCondition.id);

            // Check if the source of the parent result is cyclic prerequisite
            if (parentResult.source == GBFeatureSource.cyclicPrerequisite) {
              final featureResultWhenCircularDependencyDetected = prepareResult(
                value: null, // Corresponds to .null in Swift
                source: GBFeatureSource.cyclicPrerequisite,
              );

              onFeatureUsageCallbackWithUser?.call(
                  featureKey, featureResultWhenCircularDependencyDetected);

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
                logger.d('Feature blocked by prerequisite');
                final featureResultWhenBlockedByPrerequisite = prepareResult(
                  value: null, // Corresponds to .null in Swift
                  source: GBFeatureSource.prerequisite,
                );

                onFeatureUsageCallbackWithUser?.call(
                    featureKey, featureResultWhenBlockedByPrerequisite);

                return featureResultWhenBlockedByPrerequisite;
              }

              // Non-blocking prerequisite evaluation failed; continue to the next rule
              continue ruleLoop;
            }
          }
        }
        if (rule.filters != null) {
          if (GBUtils.isFilteredOut(
              rule.filters!, context.userContext.attributes ?? {})) {
            logger.d('Skip rule because of filters');
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
            logger.d('Skip rule because of condition');
            continue; // Skip to the next rule
          }

          // Check if the user is included in the rollout
          bool isUserIncluded = GBUtils.isIncludedInRollout(
            context.userContext.attributes ?? {},
            rule.seed ?? featureKey,
            rule.hashAttribute,
            (context.options.stickyBucketService != null &&
                    (rule.disableStickyBucketing != true))
                ? rule.fallbackAttribute
                : null,
            rule.range,
            rule.coverage,
            rule.hashVersion,
          );

          if (!isUserIncluded) {
            logger.d('Skip rule because user not included in rollout');
            continue; // Skip to the next rule
          }

          // Handle tracks if present
          if (rule.tracks != null) {
            for (var track in rule.tracks!) {
              if (track.experiment != null && track.result != null) {
                var experiment = track.experiment!;
                var result = track.result!;
                if (!ExperimentHelper.shared.isTracked(experiment, result)) {
                  context.options.trackingCallBackWithUser!(GBTrackData(
                      experiment: experiment, experimentResult: result));
                }
              }
            }
          }

          final forcedFeatureResult = prepareResult(
              value: rule.force!,
              source: GBFeatureSource.force,
              ruleId: rule.id);
          onFeatureUsageCallbackWithUser?.call(featureKey, forcedFeatureResult);
          return forcedFeatureResult;
        } else {
          // Prefer contextualVariations when the payload provides them, even
          // if the rule has no explicit `contextualBanditRef`. This gives
          // graceful degradation: SDKs without bandit support see
          // `variations == null` and skip; SDKs with support pick up the
          // bandit variations here.
          final effectiveVariations =
              rule.contextualVariations ?? rule.variations;
          if (effectiveVariations == null) {
            // If not, skip this rule
            continue;
          } else {
            // Convert the rule to an Experiment object
            GBExperiment exp = GBExperiment(
              key: rule.key ?? featureKey,
              variations: effectiveVariations,
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

            // If this rule points at a contextual-bandit definition, resolve
            // the per-user leaf and override the experiment's weights before
            // bucketing.
            if (rule.contextualBanditRef != null) {
              _buildContextualBanditExperiment(
                  exp, rule.contextualBanditRef!, context);
            }

            GBExperimentResult result = ExperimentEvaluator()
                .evaluateExperiment(context, exp, featureId: featureKey);

            // Keep the bandit selection only when the user was actually
            // hash-bucketed into the experiment. If they were force-assigned
            // or filtered out, the selection is meaningless for tracking.
            if (exp.contextualBandit != null &&
                !((result.hashUsed ?? false) && result.inExperiment)) {
              exp.contextualBandit = null;
            }

            // Check if the result is in the experiment and not a passthrough
            if (result.inExperiment && !(result.passthrough ?? false)) {
              // Return the result value and source if the result is successful
              final experimentFeatureResult = prepareResult(
                  value: result.value,
                  source: GBFeatureSource.experiment,
                  experiment: exp,
                  result: result,
                  ruleId: rule.id);
              onFeatureUsageCallbackWithUser?.call(
                  featureKey, experimentFeatureResult);
              return experimentFeatureResult;
            }
          }
        }
      }
    }
    final defaultFeatureResult = prepareResult(
        value: targetFeature.defaultValue,
        source: GBFeatureSource.defaultValue);
    onFeatureUsageCallbackWithUser?.call(featureKey, defaultFeatureResult);
    return defaultFeatureResult;
  }

  /// This is a helper method to create a FeatureResult object.
  /// Besides the passed-in arguments, there are two derived values -
  /// on and off, which are just the value cast to booleans.
  GBFeatureResult prepareResult(
      {dynamic value,
      required GBFeatureSource source,
      GBExperiment? experiment,
      GBExperimentResult? result,
      String? ruleId = ""}) {
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
        ruleId: ruleId);
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

  /// Applies a contextual-bandit definition to [experiment] before bucketing:
  /// selects the leaf whose condition matches the user, overrides the
  /// experiment's weights, and records the selection on
  /// [GBExperiment.contextualBandit].
  ///
  /// If the reference is missing from the payload the experiment is left
  /// untouched (aggregate weights apply). If a definition is present but no
  /// leaf matches, a fallback marker ([kContextualBanditFallbackLeafId]) is
  /// recorded and the experiment's existing or equal weights are used.
  void _buildContextualBanditExperiment(
    GBExperiment experiment,
    String contextualBanditRef,
    EvaluationContext context,
  ) {
    final contextualBandits = context.globalContext.contextualBandits;
    final definitionJson = contextualBandits?[contextualBanditRef];
    if (definitionJson == null) {
      logger.d(
          'Contextual bandit ref not found in payload, using aggregate weights: '
          '$contextualBanditRef');
      return;
    }

    ContextualBanditDefinition definition;
    try {
      definition = ContextualBanditDefinition.fromJson(
        definitionJson is Map<String, dynamic>
            ? definitionJson
            : Map<String, dynamic>.from(definitionJson as Map),
      );
    } catch (e) {
      logger.d(
          'Contextual bandit definition failed to parse, using aggregate weights: '
          '$contextualBanditRef ($e)');
      return;
    }

    ContextualBanditContext? leaf;
    final contexts = definition.contexts;
    if (contexts != null && contexts.isNotEmpty) {
      try {
        leaf = _selectContextualBanditLeaf(contexts, context);
      } catch (e) {
        logger.d(
            'Contextual bandit leaf selection failed, using fallback weights: '
            '$contextualBanditRef ($e)');
      }
    }

    if (leaf != null) {
      experiment.weights = leaf.weights;
      experiment.contextualBandit = ContextualBandit(
        leafId: leaf.leafId,
        variationWeights: leaf.weights,
        banditVersion: definition.banditVersion,
      );
      return;
    }

    final variationCount = experiment.variations.length;
    final fallbackWeights =
        experiment.weights ?? GBUtils.getEqualWeights(variationCount);
    experiment.contextualBandit = ContextualBandit(
      leafId: kContextualBanditFallbackLeafId,
      variationWeights: fallbackWeights,
      banditVersion: definition.banditVersion,
    );
  }

  ContextualBanditContext? _selectContextualBanditLeaf(
    List<ContextualBanditContext> contexts,
    EvaluationContext context,
  ) {
    final attributes = context.userContext.attributes ?? <String, dynamic>{};
    final savedGroups = context.globalContext.savedGroups;
    for (final leaf in contexts) {
      final condition = leaf.condition ?? <String, dynamic>{};
      if (GBConditionEvaluator()
          .isEvalCondition(attributes, condition, savedGroups)) {
        return leaf;
      }
    }
    return null;
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
