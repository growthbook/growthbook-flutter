import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Version reported on every ingested event and in the plugin's `User-Agent`.
const String gbSdkVersion = '4.4.0'; // x-release-please-version

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

  /// Sends any buffered data without shutting down.
  ///
  /// Separate from [close] because an app heading to the background needs its
  /// buffer delivered but expects to keep recording when it returns; [close]
  /// ends the plugin for good. Defaults to a no-op so existing plugins keep
  /// working unchanged.
  Future<void> flush() async {}

  /// Called when the SDK is disposed. Implementations should flush any buffered
  /// data before returning.
  Future<void> close();
}

// ---------------------------------------------------------------------------
// Ingest event models
// ---------------------------------------------------------------------------

/// Attribute keys the ingestor reads as top-level columns. Everything else is
/// carried in `context_json`.
///
/// Mirrors the Swift and Kotlin SDKs exactly — dropping a key here silently
/// stops it being queryable as a column on the ingested event.
const Set<String> _topLevelAttributeKeys = {
  'user_id',
  'device_id',
  'anonymous_id',
  'id',
  'page_id',
  'session_id',
  'utmCampaign',
  'utmContent',
  'utmMedium',
  'utmSource',
  'utmTerm',
  'pageTitle',
};

/// Builds the flat payload the ingest endpoint expects.
///
/// The event's own fields go in `properties_json`, the unit's identity is
/// promoted to top-level columns, and whatever attributes are left land in
/// `context_json`. Sending the attributes as one undivided blob parses, but
/// the identity columns come back empty, so the events cannot be joined to a
/// user at all.
///
/// `url` is always empty on Flutter: the plugin callbacks carry attributes but
/// no URL, and widening [GrowthBookPlugin] to pass one would break every app
/// that implements it. The Swift and Kotlin SDKs send an empty string for the
/// same reason.
Map<String, dynamic> _buildIngestPayload({
  required String eventName,
  required Map<String, dynamic> properties,
  required Map<String, dynamic> attributes,
}) {
  String? asString(String key) {
    final value = attributes[key];
    return value is String ? value : null;
  }

  final context = Map<String, dynamic>.fromEntries(
    attributes.entries
        .where((entry) => !_topLevelAttributeKeys.contains(entry.key)),
  );

  return {
    'event_name': eventName,
    'properties_json': properties,
    'sdk_language': 'dart',
    'sdk_version': gbSdkVersion,
    'url': '',
    'context_json': context,
    // Identity columns are always written, null when the attribute is missing
    // or is not a string. Omitting them instead would leave the column absent
    // rather than explicitly empty.
    'user_id': asString('user_id'),
    'device_id':
        asString('device_id') ?? asString('anonymous_id') ?? asString('id'),
    'page_id': asString('page_id'),
    'session_id': asString('session_id'),
    // Campaign fields are optional: absent means absent, not null.
    if (asString('utmSource') != null) 'utm_source': asString('utmSource'),
    if (asString('utmMedium') != null) 'utm_medium': asString('utmMedium'),
    if (asString('utmCampaign') != null)
      'utm_campaign': asString('utmCampaign'),
    if (asString('utmTerm') != null) 'utm_term': asString('utmTerm'),
    if (asString('utmContent') != null) 'utm_content': asString('utmContent'),
    if (asString('pageTitle') != null) 'page_title': asString('pageTitle'),
  };
}

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
    this.hashAttribute,
    this.hashValue,
  });

  factory GBExperimentViewedEvent.from(
    GBExperiment experiment,
    GBExperimentResult result,
    Map<String, dynamic> attributes,
  ) {
    return GBExperimentViewedEvent(
      experimentId: experiment.key,
      variationId: result.key,
      hashAttribute: result.hashAttribute,
      hashValue: result.hashValue,
      attributes: attributes,
    );
  }

  static const String eventName = 'Experiment Viewed';

  final String experimentId;

  /// The assigned variation's key, not its index.
  ///
  /// Analysis joins exposures on the key, so sending the array index means an
  /// experiment with custom variation keys gets no matched exposures at all —
  /// the events arrive and simply never line up.
  final String variationId;

  /// The attribute the assignment was made on, and its value. Without them an
  /// exposure cannot be attributed to the unit it belongs to.
  final String? hashAttribute;
  final String? hashValue;

  final Map<String, dynamic> attributes;

  @override
  Map<String, dynamic> toJson() => _buildIngestPayload(
        eventName: eventName,
        properties: {
          'experimentId': experimentId,
          'variationId': variationId,
          if (hashAttribute != null) 'hashAttribute': hashAttribute,
          if (hashValue != null) 'hashValue': hashValue,
        },
        attributes: attributes,
      );
}

class GBFeatureEvaluatedEvent extends GBIngestEvent {
  const GBFeatureEvaluatedEvent({
    required this.feature,
    required this.value,
    required this.source,
    required this.ruleId,
    required this.variationId,
    required this.attributes,
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
      ruleId: result.source == GBFeatureSource.defaultValue
          ? r'$default'
          : (result.ruleId ?? ''),
      variationId: result.experimentResult?.key ?? '',
      attributes: attributes,
    );
  }

  static const String eventName = 'Feature Evaluated';

  final String feature;
  final dynamic value;
  final String source;

  /// Normalized the way the other SDKs do it: `$default` when the value came
  /// from the feature's default, and an empty string rather than null when a
  /// rule carries no id. Left as-is, the same evaluation produces a different
  /// stored value on each platform.
  final String ruleId;

  /// The variation key when the value came from an experiment, empty otherwise.
  final String variationId;

  final Map<String, dynamic> attributes;

  @override
  Map<String, dynamic> toJson() => _buildIngestPayload(
        eventName: eventName,
        properties: {
          'feature': feature,
          'source': source,
          if (value != null) 'value': value,
          'ruleId': ruleId,
          'variationId': variationId,
        },
        attributes: attributes,
      );
}
