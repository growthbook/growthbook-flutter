import 'package:json_annotation/json_annotation.dart';

part 'remote_eval_model.g.dart';

/// A Feature object consists of possible values plus rules for how to assign values to users.
@JsonSerializable()
class RemoteEvalModel {
  RemoteEvalModel({
    this.attributes,
    this.forcedFeatures,
    this.forcedVariations,
  });

  final Map<String, dynamic>? attributes;
  final List<dynamic>? forcedFeatures;
  final Map<String, dynamic>? forcedVariations;

  factory RemoteEvalModel.fromJson(Map<String, dynamic> json) =>
      _$RemoteEvalModelFromJson(json);

  Map<String, dynamic> toJson() => _$RemoteEvalModelToJson(this);
}

/// Everything needed to issue a single remote-evaluation request.
///
/// Built fresh for every round rather than captured once, so a refresh always
/// carries the current attributes, forced features and forced variations.
class RemoteEvalRequest {
  RemoteEvalRequest({
    required this.apiUrl,
    required this.payload,
    this.cacheKey,
  });

  final String apiUrl;
  final RemoteEvalModel payload;

  /// Identifies the evaluation inputs this request carries. A cached response
  /// is only served again for a request with the same key, so features
  /// evaluated for one user are never shown to another.
  final String? cacheKey;
}

/// Supplies the request for the next remote-evaluation round, or `null` when
/// remote evaluation cannot run (e.g. no URL is configured).
typedef RemoteEvalRequestProvider = RemoteEvalRequest? Function();
