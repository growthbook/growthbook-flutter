import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/converter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tuple/tuple.dart';

part 'constant.g.dart';

/// Constant class for GrowthBook
class Constant {
  /// ID Attribute key.
  static String idAttribute = 'id';

  /// Identifier for Caching Feature Data in Internal Storage File
  static String featureCache = 'FeatureCache';

  /// Context Path for Fetching Feature Details - Web Service
  static String featurePath = 'api/features/';
}

/// Triple Tuple for GrowthBook Namespaces
/// It has ID, StartRange & EndRange
typedef GBNameSpace = Tuple3<String, double, double>;

/// Double Tuple for GrowthBook Ranges
typedef GBBucketRange = Tuple2<double, double>;

/// Type Alias for Feature in GrowthBook
/// Represents json response in this case.
typedef GBFeatures = Map<String, GBFeature>;

/// Type Alias for Condition Element in GrowthBook Rules
typedef GBCondition = Object;

/// Handler for Refresh Cache Request
/// It updates back whether cache was refreshed or not
typedef GBCacheRefreshHandler = void Function(bool);

/// A function that takes experiment and result as arguments.
typedef TrackingCallBack = void Function(GBExperiment, GBExperimentResult);

/// GrowthBook Error Class to handle any error / exception scenario

class GBError {
  /// Error Message for the caught error / exception.
  final Object? error;

  /// Error Stacktrace for the caught error / exception.
  final String stackTrace;

  const GBError({
    this.error,
    required this.stackTrace,
  });
}

/// Object used for mutual exclusion and filtering users out of experiments based on random hashes
@JsonSerializable(createToJson: false)
class GBFilter {
  GBFilter({
    required this.seed,
    required this.ranges,
    required this.attribute,
    required this.hashVersion,
  });

  final String seed;

  @Tuple2Converter()
  final List<GBBucketRange> ranges;

  final String? attribute;

  final int? hashVersion;

  factory GBFilter.fromJson(Map<String, dynamic> value) =>
      _$GBFilterFromJson(value);
}

/// Meta info about the variations
@JsonSerializable(createToJson: false)
class GBVariationMeta {
  GBVariationMeta({
    this.key,
    this.name,
    this.passthrough,
  });

  final String? key;

  final String? name;

  final bool? passthrough;

  factory GBVariationMeta.fromJson(Map<String, dynamic> value) =>
      _$GBVariationMetaFromJson(value);
}

/// Used for remote feature evaluation to trigger the `TrackingCallback`
@JsonSerializable(createToJson: false)
class GBTrackData {
  GBTrackData({
    required this.experiment,
    required this.experimentResult,
  });

  final GBExperiment experiment;

  final GBExperimentResult experimentResult;

  factory GBTrackData.fromJson(Map<String, dynamic> value) =>
      _$GBTrackDataFromJson(value);
}
