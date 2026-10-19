import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Where the features a [GBFeatureRefreshEvent] reports came from.
enum GBFeatureRefreshSource {
  /// Fetched from the API — a features request, a remote evaluation, or a
  /// streamed update. These are indistinguishable at this layer, so all three
  /// arrive as [network].
  network,

  /// Read from the local cache, which happens on startup and before the first
  /// network round of a session.
  cache,

  /// The server answered 304 Not Modified: the cached definitions are still
  /// current, so [GBFeatureRefreshEvent.features] is unchanged.
  notModified,
}

/// Describes one attempt to refresh the feature definitions.
///
/// Delivered to every listener registered through
/// [GrowthBookSDK.addFeatureRefreshListener].
class GBFeatureRefreshEvent {
  GBFeatureRefreshEvent({
    required this.success,
    required this.source,
    required GBFeatures features,
    this.error,
  }) : features = Map.unmodifiable(features);

  /// Whether the refresh produced usable definitions. False only for a failed
  /// fetch, in which case [error] describes it and [features] still holds the
  /// definitions evaluation is running against.
  final bool success;

  /// Where the definitions came from.
  final GBFeatureRefreshSource source;

  /// The feature definitions in effect after this refresh.
  ///
  /// The map itself is unmodifiable, so a listener cannot add, replace or
  /// remove a definition. The [GBFeature] values, however, are the SDK's own
  /// mutable objects rather than copies — mutating one changes what evaluation
  /// returns. Read them; do not write to them. (They are not copied because a
  /// copy deep enough to be safe means re-encoding every definition on every
  /// refresh, and `GBFeature.toJson` shares `defaultValue` and `rules` by
  /// reference, so a cheaper copy would not be safe anyway.)
  final GBFeatures features;

  /// Why the refresh failed, when it did.
  final GBError? error;

  @override
  String toString() => 'GBFeatureRefreshEvent(success: $success, '
      'source: ${source.name}, features: ${features.length}'
      '${error != null ? ', error: ${error.runtimeType}' : ''})';
}

/// Called after every feature refresh attempt. Register one with
/// [GrowthBookSDK.addFeatureRefreshListener].
typedef GBFeatureRefreshListener = void Function(GBFeatureRefreshEvent event);
