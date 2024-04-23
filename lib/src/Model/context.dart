import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';

/// Defines the GrowthBook context.
class GBContext {
  GBContext({
    this.apiKey,
    this.encryptionKey,
    this.hostURL,
    this.enabled,
    this.attributes,
    this.forcedVariation,
    this.stickyBucketAssignmentDocs,
    this.stickyBucketIdentifierAttributes,
    this.stickyBucketService,
    this.remoteEval,
    this.qaMode = false,
    this.trackingCallBack,
    this.features = const <String, GBFeature>{},
    this.backgroundSync
  });

  /// Registered API key for GrowthBook SDK.
  String? apiKey;

  /// Encryption key for encrypted features.
  String? encryptionKey;

  /// Host URL for GrowthBook
  String? hostURL;

  /// Switch to globally disable all experiments. Default true.
  bool? enabled;

  /// Map of user attributes that are used to assign variations
  Map<String, dynamic>? attributes;

  /// Force specific experiments to always assign a specific variation (used for QA).
  Map<String, dynamic>? forcedVariation;

  Map<StickyAttributeKey, StickyAssignmentsDocument>? stickyBucketAssignmentDocs;

  List<String>? stickyBucketIdentifierAttributes;

  StickyBucketService? stickyBucketService;

  bool? remoteEval;

  /// If true, random assignment is disabled and only explicitly forced variations are used.
  bool qaMode;

  /// A function that takes experiment and result as arguments.
  TrackingCallBack? trackingCallBack;

  /// Keys are unique identifiers for the features and the values are Feature objects.
  /// Feature definitions - To be pulled from API / Cache
  GBFeatures features;

  ///Disable background streaming connection
  bool? backgroundSync;
}