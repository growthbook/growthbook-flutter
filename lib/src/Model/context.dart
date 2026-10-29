import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

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
    this.remoteGroupIds,
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

  /// The ids of the remote saved groups the user is in, resolved by the app.
  /// `null` means unresolved, which is not the same as no groups: see
  /// [GrowthBookSDK.setRemoteGroupIds].
  List<String>? remoteGroupIds;

  /// The attributes conditions see: [attributes], with the resolved remote
  /// saved group ids (when set) as [Constant.remoteGroupIdsAttribute], over any
  /// value the attributes set for it. Remote evaluation sends these too, so the
  /// server sees the same groups.
  Map<String, dynamic>? get evaluationAttributes {
    final ids = remoteGroupIds;
    if (ids == null) return attributes;
    return {...?attributes, Constant.remoteGroupIdsAttribute: ids};
  }

  /// Whether [savedGroups] has a remote entry.
  bool get hasRemoteSavedGroups =>
      savedGroups?.values
          .any((entry) => entry is Map && entry['type'] == 'remote') ??
      false;

  String? getFeaturesURL() => _buildUrl('/api/features/');

  String? getRemoteEvalUrl() => _buildUrl('/api/eval/');

  String? _buildUrl(String endpoint) {
    if (hostURL == null || apiKey == null) return null;

    final uri = Uri.parse(hostURL!);

    var basePath = uri.path;
    while (basePath.endsWith('/')) {
      basePath = basePath.substring(0, basePath.length - 1);
    }

    return uri.replace(path: '$basePath$endpoint$apiKey').toString();
  }
}
