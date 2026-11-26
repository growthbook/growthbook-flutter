import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/feature_url_builder.dart';

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
    SavedGroupsValues? savedGroups,
    this.url,
    this.streamingHost,
    this.apiHostRequestHeaders,
    this.streamingHostRequestHeaders,
    this.remoteGroupIds,
  })  : _savedGroups = savedGroups,
        _hasRemoteSavedGroups = _containsRemoteGroup(savedGroups);

  /// Registered API key for GrowthBook SDK.
  String? apiKey;

  /// Encryption key for encrypted features.
  String? encryptionKey;

  /// Host URL for GrowthBook
  String? hostURL;

  /// Host serving the streaming (server-sent events) endpoint, when it differs
  /// from [hostURL] — a GrowthBook Proxy in front of a CDN, for example.
  /// Falls back to [hostURL] when null.
  String? streamingHost;

  /// Headers sent with every features request and remote-evaluation request.
  /// Meant for deployments behind an authenticated gateway or proxy.
  Map<String, String>? apiHostRequestHeaders;

  /// Headers sent with the streaming connection, including its reconnects.
  Map<String, String>? streamingHostRequestHeaders;

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
  SavedGroupsValues? get savedGroups => _savedGroups;

  set savedGroups(SavedGroupsValues? value) {
    _savedGroups = value;
    _hasRemoteSavedGroups = _containsRemoteGroup(value);
  }

  SavedGroupsValues? _savedGroups;

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

  /// Whether [savedGroups] has a remote entry. Computed when [savedGroups]
  /// changes rather than on each read, since every feature and experiment read
  /// checks it.
  bool get hasRemoteSavedGroups => _hasRemoteSavedGroups;
  bool _hasRemoteSavedGroups;

  static bool _containsRemoteGroup(SavedGroupsValues? savedGroups) =>
      savedGroups?.values
          .any((entry) => entry is Map && entry['type'] == 'remote') ??
      false;

  String? getFeaturesURL() => _urlBuilder.buildUrl(apiKey);

  String? getRemoteEvalUrl() => _urlBuilder.buildUrl(
        apiKey,
        featureRefreshStrategy:
            FeatureRefreshStrategy.SERVER_SENT_REMOTE_FEATURE_EVAL,
      );

  /// Streaming endpoint, served from [streamingHost] when one is configured and
  /// from [hostURL] otherwise.
  String? getStreamingURL() => _urlBuilder.buildUrl(
        apiKey,
        featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS,
      );

  FeatureURLBuilder get _urlBuilder => FeatureURLBuilder(
        apiHost: hostURL,
        streamingHost: streamingHost,
      );
}
