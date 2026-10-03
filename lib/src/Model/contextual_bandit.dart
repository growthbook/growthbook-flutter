import 'package:json_annotation/json_annotation.dart';

part 'contextual_bandit.g.dart';

/// A single leaf of a [ContextualBanditDefinition]: a targeting `condition`
/// paired with the backend-computed variation `weights` to apply when that
/// condition matches the user.
///
/// Part of the read-only contextual bandit payload; instances are deserialized
/// from the feature API response and never mutated during evaluation.
@JsonSerializable()
class ContextualBanditContext {
  ContextualBanditContext({
    this.leafId,
    this.condition,
    this.weights,
  });

  /// Identifier of this leaf within the bandit definition. Surfaced on
  /// [GBExperimentResult] so exposures can be attributed back to the segment
  /// that produced the weights.
  final int? leafId;

  /// Targeting condition evaluated against the user's attributes. A `null` or
  /// empty condition matches every user.
  final Map<String, dynamic>? condition;

  /// Variation weights to apply when this leaf matches. Must align with the
  /// experiment's variation count and, like any weights, sum to 1.
  final List<double>? weights;

  factory ContextualBanditContext.fromJson(Map<String, dynamic> json) =>
      _$ContextualBanditContextFromJson(json);

  Map<String, dynamic> toJson() => _$ContextualBanditContextToJson(this);
}

/// A contextual bandit definition shipped in the feature payload under
/// `contextualBandits`, keyed by the `contextualBanditRef` a feature rule
/// points at.
///
/// A contextual bandit assigns per-segment variation weights: each
/// [ContextualBanditContext] ("leaf") carries a targeting condition and the
/// weights to use when it matches. The weights themselves are computed on the
/// GrowthBook backend; the SDK only selects the matching leaf and applies its
/// weights before bucketing.
@JsonSerializable()
class ContextualBanditDefinition {
  ContextualBanditDefinition({
    this.banditVersion,
    this.contexts,
  });

  /// Monotonic version of the backend-computed weights, echoed onto
  /// [GBExperimentResult] so exposures can be attributed to the weight
  /// generation that produced them.
  final int? banditVersion;

  /// Ordered leaves. Leaves are evaluated top-to-bottom and the first whose
  /// condition matches the user wins; if none match, the SDK falls back to
  /// aggregate or equal weights.
  final List<ContextualBanditContext>? contexts;

  factory ContextualBanditDefinition.fromJson(Map<String, dynamic> json) =>
      _$ContextualBanditDefinitionFromJson(json);

  Map<String, dynamic> toJson() => _$ContextualBanditDefinitionToJson(this);
}

/// The outcome of resolving a [ContextualBanditDefinition] for a given user:
/// the selected leaf and the weights that were applied to the [GBExperiment].
/// Attached to the experiment during evaluation and, when the user is bucketed
/// in, copied onto [GBExperimentResult] for tracking.
///
/// A [leafId] of `-1` means no leaf matched (or the definition was missing)
/// and the experiment fell back to its aggregate or equal weights.
class ContextualBandit {
  ContextualBandit({
    this.leafId,
    this.variationWeights,
    this.banditVersion,
  });

  /// The matched leaf's id, or `-1` when no leaf matched and fallback weights
  /// were used.
  final int? leafId;

  /// The weights actually applied to the experiment for this user.
  final List<double>? variationWeights;

  /// The bandit version of the definition that produced these weights.
  final int? banditVersion;
}

/// Sentinel value stored in [ContextualBandit.leafId] when no leaf matched and
/// the SDK fell back to the experiment's aggregate or equal weights.
const int kContextualBanditFallbackLeafId = -1;
