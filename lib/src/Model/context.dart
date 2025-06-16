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
    this.remoteEval = false,
    this.qaMode = false,
    this.trackingCallBack,
    this.featureUsageCallback,
    this.features = const <String, GBFeature>{},
    this.backgroundSync = false,
    this.savedGroups,
    this.url,
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

  Map<StickyAttributeKey, StickyAssignmentsDocument>?
      stickyBucketAssignmentDocs;

  List<String>? stickyBucketIdentifierAttributes;

  StickyBucketService? stickyBucketService;

  bool remoteEval;

  /// If true, random assignment is disabled and only explicitly forced variations are used.
  bool qaMode;

  /// A function that takes experiment and result as arguments.
  TrackingCallBack? trackingCallBack;

  /// A callback that will be invoked every time a feature is viewed. Listen for feature usage events
  GBFeatureUsageCallback? featureUsageCallback;

  /// Keys are unique identifiers for the features and the values are Feature objects.
  /// Feature definitions - To be pulled from API / Cache
  GBFeatures features;

  ///Disable background streaming connection
  bool backgroundSync;

  ///Once you define your Saved Groups, you can easily reference them from any Feature rule or Experiment.
  ///Updates to saved groups apply immediately and will be instantly propagated to all matching Features and Experiments.
  ///There are two types of Saved Groups:
  ///ID Lists - Pick an attribute and define a list of values directly within the GrowthBook UI.
  ///For example, you can make an Admin group and add the userId of all of your admins.
  ///Condition Groups - Configure advanced targeting rules based on a user's attributes. For example,
  ///"all users located in the US on a mobile device".
  SavedGroupsValues? savedGroups;

  ///A URL string that is used for experiment evaluation, as well as forcing feature values.
  String? url;

  String? getFeaturesURL() {
    if (hostURL != null && apiKey != null) {
      return '$hostURL/api/features/$apiKey';
    } else {
      return null;
    }
  }

  String? getRemoteEvalUrl() {
    if (hostURL != null && apiKey != null) {
      return '$hostURL/api/eval/$apiKey';
    } else {
      return null;
    }
  }
}
