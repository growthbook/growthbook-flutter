import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// A plugin that receives lifecycle and evaluation events from the GrowthBook SDK.
///
/// Plugin methods are always called after the existing tracking callbacks fire.
/// Any errors thrown inside plugin methods must not propagate to callers.
abstract class GrowthBookPlugin {
  /// Called once when the SDK is initialized.
  void initialize(String clientKey);

  /// Called every time a user is exposed to an experiment variation.
  void onExperimentViewed(GBExperiment experiment, GBExperimentResult result);

  /// Called every time a feature flag is evaluated.
  void onFeatureEvaluated(String featureKey, GBFeatureResult result);

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
  });

  factory GBExperimentViewedEvent.from(
      GBExperiment experiment, GBExperimentResult result) {
    return GBExperimentViewedEvent(
      experimentKey: experiment.key,
      variationId: result.variationID ?? 0,
      hashAttribute: result.hashAttribute,
      hashValue: result.hashValue,
    );
  }

  final String event = 'experiment_viewed';
  final String experimentKey;
  final int variationId;
  final String? hashAttribute;
  final String? hashValue;

  @override
  Map<String, dynamic> toJson() => {
        'event': event,
        'experimentKey': experimentKey,
        'variationId': variationId,
        if (hashAttribute != null) 'hashAttribute': hashAttribute,
        if (hashValue != null) 'hashValue': hashValue,
      };
}

class GBFeatureEvaluatedEvent extends GBIngestEvent {
  const GBFeatureEvaluatedEvent({
    required this.featureKey,
    required this.value,
    required this.source,
    this.ruleId,
  });

  factory GBFeatureEvaluatedEvent.from(String featureKey, GBFeatureResult result) {
    return GBFeatureEvaluatedEvent(
      featureKey: featureKey,
      value: result.value,
      source: result.source?.name ?? 'unknownFeature',
      ruleId: result.ruleId,
    );
  }

  final String event = 'feature_evaluated';
  final String featureKey;
  final dynamic value;
  final String source;
  final String? ruleId;

  @override
  Map<String, dynamic> toJson() => {
        'event': event,
        'featureKey': featureKey,
        'value': value,
        'source': source,
        if (ruleId != null && ruleId!.isNotEmpty) 'ruleId': ruleId,
      };
}

/// The payload POSTed to `{ingestorHost}/track`.
class GBIngestPayload {
  const GBIngestPayload({required this.clientKey, required this.events});

  final String clientKey;
  final List<GBIngestEvent> events;

  Map<String, dynamic> toJson() => {
        'client_key': clientKey,
        'events': events.map((e) => e.toJson()).toList(),
      };
}
