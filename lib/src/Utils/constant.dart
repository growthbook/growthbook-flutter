import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:tuple/tuple.dart';

/// Constant class for GrowthBook
class Constant {
  /// ID Attribute key.
  static String idAttribute = 'id';

  /// Identifier for Caching Feature Data in Internal Storage File
  static String featureCache = 'featureCache';

  static String savedGroupsCache = 'savedGroupCache';

  /// Context Path for Fetching Feature Details - Web Service
  static String featurePath = 'api/features';

  /// SSE path
  static String eventsPath = "sub";
}

/// Handler for cache refresh notifications (legacy, error-unaware).
///
/// Prefer [CacheRefreshHandlerV2], which also receives the [GBError]
/// that caused the failure. This signature is kept for backwards
/// compatibility and will be removed in a future major release.
@Deprecated('Use CacheRefreshHandlerV2 for error-aware refresh callbacks')
typedef CacheRefreshHandler = void Function(bool);

/// Handler for cache refresh notifications with error context.
///
/// Called with `(true, null)` on successful refresh (fresh data or
/// 304 Not Modified), and `(false, error)` on failure so consumers
/// can distinguish network errors from parse/decryption errors.
typedef CacheRefreshHandlerV2 = void Function(bool, GBError?);

/// Triple Tuple for GrowthBook Namespaces
/// It has ID, StartRange & EndRange
typedef GBNameSpace = Tuple3<String, double, double>;

/// Double Tuple for GrowthBook Ranges
typedef GBBucketRange = List<double>;

/// Type Alias for Feature in GrowthBook
/// Represents json response in this case.
typedef GBFeatures = Map<String, GBFeature>;

/// Type Alias for Condition Element in GrowthBook Rules
typedef GBCondition = Map<String, dynamic>;

/// Handler for Refresh Cache Request
/// It updates back whether cache was refreshed or not
@Deprecated('Use CacheRefreshHandlerV2 for error-aware refresh callbacks')
typedef GBCacheRefreshHandler = void Function(bool);

typedef GBStickyBucketingService = LocalStorageStickyBucketService;

/// A function that takes experiment and result as arguments.
typedef TrackingCallBack = void Function(GBTrackData trackData);

typedef ExperimentRunCallback = void Function(GBExperiment, GBExperimentResult);

typedef GBFeatureUsageCallback = void Function(String, GBFeatureResult);

typedef SavedGroupsValues = Map<String, dynamic>;

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

/// Used for remote feature evaluation to trigger the `TrackingCallback`
class GBTrackData {
  GBTrackData({
    required this.experiment,
    required this.experimentResult,
  });

  final GBExperiment experiment;

  final GBExperimentResult experimentResult;
}

class AssignedExperiment {
  AssignedExperiment({
    required this.experiment,
    required this.experimentResult,
  });

  final GBExperiment experiment;
  final GBExperimentResult experimentResult;
}
