import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';
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

typedef CacheRefreshHandler = void Function(bool);

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
typedef GBCacheRefreshHandler = void Function(bool);

typedef GBStickyBucketingService = LocalStorageStickyBucketService;

/// A function that takes experiment and result as arguments.
typedef TrackingCallBack = void Function(GBExperiment, GBExperimentResult);

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
