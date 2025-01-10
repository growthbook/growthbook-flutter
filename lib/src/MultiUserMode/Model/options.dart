import 'package:growthbook_sdk_flutter/src/MultiUserMode/constant.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';
import 'package:growthbook_sdk_flutter/src/Utils/feature_url_builder.dart';

class Options {
  Options({
    this.enabled,
    required this.isQaMode,
    required this.isCacheDisabled,
    this.url,
    this.apiHost,
    this.clientKey,
    this.decryptionKey,
    this.stickyBucketIdentifierAttributes,
    this.stickyBucketService,
    this.trackingCallBackWithUser,
    this.featureUsageCallbackWithUser,
    this.refreshStrategy = FeatureRefreshStrategy.STALE_WHILE_REVALIDATE,
    this.featureRefreshCallback,
  });

  /// Whether globally all experiments are enabled (default: true)
  /// Switch to globally disable all experiments.
  bool? enabled;

  /// If true, random assignment is disabled and only explicitly forced variations are used.
  bool isQaMode;

  // Default - true.
  bool isCacheDisabled;

  // /// Boolean flag to allow URL overrides (default: false)
  // bool allowUrlOverrides;

  String? url;

  String? apiHost;

  String? clientKey;

  /// Optional decryption Key. If this is not null, featuresJson should be an encrypted payload.
  String? decryptionKey;

  /// List of user's attributes keys.
  List<String>? stickyBucketIdentifierAttributes;

  /// Service that provide functionality of Sticky Bucketing

  StickyBucketService? stickyBucketService;

  /// A function that takes {@link Experiment} and {@link ExperimentResult} as arguments.
  TrackingCallBackWithUser? trackingCallBackWithUser;

  /// A function that takes {@link String} and {@link FeatureResult} as arguments.
  /// A callback that will be invoked every time a feature is viewed. Listen for feature usage events
  FeatureUsageCallbackWithUser? featureUsageCallbackWithUser;

  FeatureRefreshStrategy? refreshStrategy;

  FeatureRefreshCallback? featureRefreshCallback;
}
