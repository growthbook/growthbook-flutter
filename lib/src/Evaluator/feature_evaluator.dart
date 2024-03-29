import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Feature Evaluator Class
/// Takes Context and Feature Key
/// Returns Calculated Feature Result against that key

class GBFeatureEvaluator {
  static GBFeatureResult evaluateFeature(GBContext context, String featureKey) {
    /// If we are not able to find feature on the basis of the passed featureKey
    /// then we are going to return unKnownFeature.

    final targetFeature = context.features.containsKey(featureKey);
    if (!targetFeature) {
      return _prepareResult(
        value: null,
        source: GBFeatureSource.unknownFeature,
      );
    }

    // Loop through the feature rules (if any)
    final rules = context.features[featureKey]?.rules;

    // Return if rules is not provided.
    if (rules != null && rules.isNotEmpty) {
      for (var rule in rules) {
        if (rule.parentConditions != null) {
          for (var parentCondition in rule.parentConditions!) {
            final parentResult = evaluateFeature(context, parentCondition.id);
            if (parentResult.source == GBFeatureSource.cyclicPrerequisite) {
              // break out for cyclic prerequisites

              return _prepareResult(
                  value: parentResult,
                  source: GBFeatureSource.cyclicPrerequisite);
            }
            final evalCondition = GBConditionEvaluator().evaluateCondition(
                context.attributes ?? {}, parentCondition.condition);

            // blocking prerequisite eval failed: feature evaluation fails

            if (!evalCondition) {
              if (parentCondition.gate!) {
                return _prepareResult(
                    value: parentResult.value,
                    source: GBFeatureSource.prerequisite);
              }
              // non-blocking prerequisite eval failed: break out of parentConditions loop, jump to the next rule
              continue;
            }
          }
        }

        /// If the rule has a condition and it evaluates to false,
        /// skip this rule and continue to the next one.

        if (rule.condition != null) {
          final attr = context.attributes ?? {};
          if (!GBConditionEvaluator()
              .evaluateCondition(attr, rule.condition!)) {
            continue;
          }
        }

        if (GBUtils.isFilteredOut(rule.filters, context.attributes)) {
          continue;
        }

        /// If rule.force is set
        if (rule.force != null) {
          /// If rule.coverage is set
          if (rule.coverage != null) {
            final key = rule.hashAttribute ?? Constant.idAttribute;
            final attributeValue = context.attributes?[key].toString() ?? '';

            if (attributeValue.isEmpty) {
              continue;
            } else {
              if (!GBUtils.isIncludedInRollout(
                context.attributes,
                rule.seed,
                rule.hashAttribute,
                rule.range,
                rule.coverage,
                rule.hashVersion,
              )) {
                continue;
              }
              // Compute a hash using the Fowler–Noll–Vo algorithm (specifically fnv32-1a)
              final hashFNV = GBUtils.hash(
                      value: attributeValue, seed: featureKey, version: 1.0) ??
                  0.0;
              // If the hash is greater than rule.coverage, skip the rule

              if (hashFNV > rule.coverage!) {
                continue;
              }
            }
          }
          return _prepareResult(
            value: rule.force,
            source: GBFeatureSource.force,
          );
        } else {
          final exp = GBExperiment(
              key: rule.key ?? featureKey,
              variations: rule.variations ?? [],
              coverage: rule.coverage,
              weights: rule.weights,
              hashAttribute: rule.hashAttribute,
              namespace: rule.namespace,
              force: rule.force,
              condition: rule.condition,
              parentConditions: rule.parentConditions);

          final result = GBExperimentEvaluator.evaluateExperiment(
            context: context,
            experiment: exp,
          );

          if (result.inExperiment ?? false) {
            return _prepareResult(
              value: result.value,
              source: GBFeatureSource.experiment,
              experiment: exp,
              experimentResult: result,
            );
          } else {
            // If result.inExperiment is false, skip this rule and continue to the next one.
            continue;
          }
        }
      }
    }
    // Return (value = defaultValue or null, source = defaultValue)
    return _prepareResult(
      value: context.features[featureKey]?.defaultValue,
      source: GBFeatureSource.defaultValue,
    );
  }

  /// This is a helper method to create a FeatureResult object.
  /// Besides the passed-in arguments, there are two derived values - on and off, which are just the value cast to booleans.
  static GBFeatureResult _prepareResult(
      {required dynamic value,
      required GBFeatureSource source,
      GBExperiment? experiment,
      GBExperimentResult? experimentResult}) {
    final isFalsy = value == null ||
        value.toString() == "false" ||
        value.toString() == '' ||
        value.toString() == "0";

    return GBFeatureResult(
        value: value,
        on: !isFalsy,
        off: isFalsy,
        source: source,
        experiment: experiment,
        experimentResult: experimentResult);
  }
}
