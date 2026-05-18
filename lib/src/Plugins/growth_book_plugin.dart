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
  Future<void> close();
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
    required this.experimentId,
    required this.variationId,
    required this.attributes,
  });

  factory GBExperimentViewedEvent.from(
    GBExperiment experiment,
    GBExperimentResult result,
    Map<String, dynamic> attributes,
  ) {
    return GBExperimentViewedEvent(
      experimentId: experiment.key,
      variationId: result.variationID ?? 0,
      attributes: attributes,
    );
  }

  final String eventName = 'Experiment Viewed';
  final String experimentId;
  final int variationId;
  final Map<String, dynamic> attributes;

  @override
  Map<String, dynamic> toJson() => {
        'event_name': eventName,
        'properties': {
          'experimentId': experimentId,
          'variationId': variationId,
        },
        'attributes': attributes,
      };
}

class GBFeatureEvaluatedEvent extends GBIngestEvent {
  const GBFeatureEvaluatedEvent({
    required this.feature,
    required this.value,
    required this.source,
    required this.attributes,
    this.ruleId,
  });

  factory GBFeatureEvaluatedEvent.from(
    String featureKey,
    GBFeatureResult result,
    Map<String, dynamic> attributes,
  ) {
    return GBFeatureEvaluatedEvent(
      feature: featureKey,
      value: result.value,
      source: result.source?.name ?? 'unknownFeature',
      ruleId: result.ruleId,
      attributes: attributes,
    );
  }

  final String eventName = 'Feature Evaluated';
  final String feature;
  final dynamic value;
  final String source;
  final String? ruleId;
  final Map<String, dynamic> attributes;

  @override
  Map<String, dynamic> toJson() => {
        'event_name': eventName,
        'properties': {
          'feature': feature,
          'value': value,
          'source': source,
          if (ruleId != null && ruleId!.isNotEmpty) 'ruleId': ruleId,
        },
        'attributes': attributes,
      };
}
