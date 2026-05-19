import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// A plugin that receives lifecycle and evaluation events from the GrowthBook SDK.
///
/// Plugin methods are always called after the existing tracking callbacks fire.
/// Any errors thrown inside plugin methods must not propagate to callers.
abstract class GrowthBookPlugin {
  /// Called once when the SDK is initialized.
  void initialize(String clientKey);

  /// Called every time a user is exposed to an experiment variation.
  void onExperimentViewed(
    GBExperiment experiment,
    GBExperimentResult result,
    Map<String, dynamic>? attributes,
  );

  /// Called every time a feature flag is evaluated.
  void onFeatureEvaluated(
    String featureKey,
    GBFeatureResult result,
    Map<String, dynamic>? attributes,
  );

  /// Called when the SDK is disposed. Implementations should flush any buffered
  /// data before returning.
  void close();
}

// ---------------------------------------------------------------------------
// Ingest event models
// ---------------------------------------------------------------------------

/// Wire format for a single event sent to the GrowthBook ingest endpoint.
sealed class GBIngestEvent {
  const GBIngestEvent();

  Map<String, dynamic> toJson();
}

class GBExperimentViewedEvent extends GBIngestEvent {
  const GBExperimentViewedEvent({
    required this.experimentKey,
    required this.variationId,
    this.hashAttribute,
    this.hashValue,
    this.attributes,
  });

  factory GBExperimentViewedEvent.from(
    GBExperiment experiment,
    GBExperimentResult result,
    Map<String, dynamic>? attributes,
  ) {
    return GBExperimentViewedEvent(
      experimentKey: experiment.key,
      variationId: result.variationID ?? 0,
      hashAttribute: result.hashAttribute,
      hashValue: result.hashValue,
      attributes: attributes,
    );
  }

  final String event = 'experiment_viewed';
  final String experimentKey;
  final int variationId;
  final String? hashAttribute;
  final String? hashValue;
  final Map<String, dynamic>? attributes;

  @override
  Map<String, dynamic> toJson() => {
        'event': event,
        'experimentKey': experimentKey,
        'variationId': variationId,
        if (hashAttribute != null) 'hashAttribute': hashAttribute,
        if (hashValue != null) 'hashValue': hashValue,
        if (attributes != null && attributes!.isNotEmpty)
          'attributes': attributes,
      };
}

class GBFeatureEvaluatedEvent extends GBIngestEvent {
  const GBFeatureEvaluatedEvent({
    required this.featureKey,
    required this.value,
    required this.source,
    this.ruleId,
    this.attributes,
  });

  factory GBFeatureEvaluatedEvent.from(
    String featureKey,
    GBFeatureResult result,
    Map<String, dynamic>? attributes,
  ) {
    return GBFeatureEvaluatedEvent(
      featureKey: featureKey,
      value: result.value,
      source: result.source?.name ?? 'unknownFeature',
      ruleId: result.ruleId,
      attributes: attributes,
    );
  }

  final String event = 'feature_evaluated';
  final String featureKey;
  final dynamic value;
  final String source;
  final String? ruleId;
  final Map<String, dynamic>? attributes;

  @override
  Map<String, dynamic> toJson() => {
        'event': event,
        'featureKey': featureKey,
        'value': value,
        'source': source,
        if (ruleId != null && ruleId!.isNotEmpty) 'ruleId': ruleId,
        if (attributes != null && attributes!.isNotEmpty)
          'attributes': attributes,
      };
}
