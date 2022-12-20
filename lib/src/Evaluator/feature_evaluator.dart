import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Feature Evaluator Class
/// Takes Context and Feature Key
/// Returns Calculated Feature Result against that key

class GBFeatureEvaluator {
  GBFeatureResult evaluateFeature(GBContext context, String featureKey) {
    /// If we are not able to find feature on the basis of the passed featureKey
    /// then we are going to return unKnownFeature.
    final targetFeature = context.features[featureKey];
    if (targetFeature == null) {
      return _prepareResult(
        value: null,
        source: GBFeatureSource.unknownFeature,
      );
    }

    // Loop through the feature rules (if any)
    final rules = targetFeature.rules;

    // Return if rules is not provided.
    if (rules != null && rules.isNotEmpty) {
      for (var rule in rules) {
        /// If the rule has a condition and it evaluates to false,
        /// skip this rule and continue to the next one.

        if (rule.condition != null) {
          final attr = context.attributes ?? {};
          if (!GBConditionEvaluator()
              .evaluateCondition(attr, rule.condition!)) {
            continue;
          }
        }

        /// If rule.force is set
        if (rule.force != null) {
          /// If rule.coverage is set
          if (rule.coverage != null) {
            final key = rule.hashAttribute ?? Constant.idAttribute;
            final attributeValue = context.attributes?[key] as String? ?? '';

            if (attributeValue.isEmpty) {
              continue;
            } else {
              // Compute a hash using the Fowler–Noll–Vo algorithm (specifically fnv32-1a)
              final hashFNV = GBUtils().hash(attributeValue + featureKey);
              // If the hash is greater than rule.coverage, skip the rule

              if (hashFNV != null && hashFNV > rule.coverage!) {
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
              force: rule.force);

          final result = GBExperimentEvaluator()
              .evaluateExperiment(context: context, experiment: exp);
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
        value: targetFeature.defaultValue,
        source: GBFeatureSource.defaultValue);
  }

  /// This is a helper method to create a FeatureResult object.
  /// Besides the passed-in arguments, there are two derived values - on and off, which are just the value cast to booleans.
  GBFeatureResult _prepareResult(
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
