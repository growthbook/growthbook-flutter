import 'dart:async';
import 'dart:convert';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';

typedef VoidCallback = void Function();

typedef OnInitializationFailure = void Function(GBError? error);

class GBSDKBuilderApp {
  GBSDKBuilderApp({
    required this.hostURL,
    required this.apiKey,
    required this.growthBookTrackingCallBack,
    this.attributes = const <String, dynamic>{},
    this.qaMode = false,
    this.enable = true,
    this.encryptionKey,
    this.forcedVariations = const <String, int>{},
    this.client,
    this.gbFeatures = const {},
    this.refreshHandler,
    this.backgroundSync,
  }) : assert(
          hostURL.endsWith('/'),
          'Invalid host url: $hostURL. The hostUrl should be end with `/`, example: `https://example.growthbook.io/`',
        );

  final String apiKey;
  final String hostURL;
  final bool? enable;
  final bool? qaMode;
  final String? encryptionKey;
  final Map<String, dynamic>? attributes;
  final Map<String, int> forcedVariations;
  final TrackingCallBack growthBookTrackingCallBack;
  final BaseClient? client;
  final GBFeatures gbFeatures;
  final bool? backgroundSync;

  CacheRefreshHandler? refreshHandler;

  Future<GrowthBookSDK> initialize() async {
    final gbContext = GBContext(
      apiKey: apiKey,
      hostURL: hostURL,
      enabled: enable,
      qaMode: qaMode,
      attributes: attributes,
      forcedVariation: forcedVariations,
      trackingCallBack: growthBookTrackingCallBack,
      encryptionKey: encryptionKey,
      features: gbFeatures,
      backgroundSync: backgroundSync,
    );

    final gb = GrowthBookSDK(
      context: gbContext,
      client: client,
      refreshHandler: refreshHandler,
      features: gbFeatures,
    );
    return gb;
  }

  GBSDKBuilderApp setRefreshHandler(CacheRefreshHandler refreshHandler) {
    this.refreshHandler = refreshHandler;
    return this;
  }
}

class GrowthBookSDK extends FeaturesFlowDelegate {
  GBCacheRefreshHandler? refreshHandler;
  late BaseClient? client;

  late FeatureViewModel featuresViewModel;
  Map<String, dynamic> attributeOverrides = <String, dynamic>{};
  Map<String, dynamic> forcedFeatures = {};

  static late GBContext gbContext;

  OnInitializationFailure? onInitializationFailure;

  GrowthBookSDK({
    required GBContext context,
    this.refreshHandler,
    this.client,
    GBFeatures? features,
  }) {
    gbContext = context;

    featuresViewModel = FeatureViewModel(
      delegate: this,
      source:
          FeatureDataSource(context: gbContext, client: client ?? DioClient()),
      encryptionKey: null,
    );

    if (features != null) {
      gbContext.features = features;
    } else {
      featuresViewModel.encryptionKey = gbContext.encryptionKey;
      refreshCache();
    }
    if (gbContext.backgroundSync != false) {
      featuresViewModel.connectBackgroundSync();
    }

    attributeOverrides = gbContext.attributes ?? {};
  }

  @override
  void featuresFetchedSuccessfully(GBFeatures gbFeatures) {
    gbContext.features = gbFeatures;
    print("features ${gbContext.features}");
    refreshHandler!(true);
  }

  @override
  void featuresFetchFailed(GBError? error) {
    onInitializationFailure?.call(error);
    refreshHandler!(false);
  }

  /// Manually Refresh Cache
  Future<void> refreshCache() async {
    await featuresViewModel.fetchFeature();
  }

  /// Get Context - Holding the complete data regarding cached features & attributes etc.
  GBContext getGBContext() {
    return gbContext;
  }

  GBFeatureResult feature(String id) {
    return GBFeatureEvaluator.evaluateFeature(
      gbContext,
      id,
    );
  }
  
  GBFeatures getFeatures() {
    return gbContext.features;
  }

  GBExperimentResult run(GBExperiment experiment) {
    return GBExperimentEvaluator.evaluateExperiment(
      context: gbContext,
      experiment: experiment,
    );
  }

  Map<StickyAttributeKey, StickyAssignmentsDocument>
      getStickyBucketAssignmentDocs() {
    return gbContext.stickyBucketAssignmentDocs ?? {};
  }

  /// Replaces the Map of user attributes that are used to assign variations
  void setAttributes(Map<String, dynamic> attributes) {
    gbContext.attributes = attributes;
  }

  void setAttributeOverrides(dynamic overrides) {
    attributeOverrides = json.decode(overrides);
    refreshStickyBucketService();
  }

  void setEncryptedFeatures(String encryptedString, String encryptionKey,
      [CryptoProtocol? subtle]) {
    CryptoProtocol crypto = subtle ?? Crypto();
    var features = crypto.getFeaturesFromEncryptedFeatures(
      encryptedString,
      encryptionKey,
    );

    if (features != null) {
      gbContext.features = features;
    }
  }

  Future<void> refreshStickyBucketService() async {
    if (gbContext.stickyBucketService != null) {
      final featureEvaluator =
          GBFeatureEvaluator(attributeOverrides: attributeOverrides);
      await featureEvaluator.refreshStickyBuckets(gbContext);
    }
  }
}
