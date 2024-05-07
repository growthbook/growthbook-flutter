import 'dart:async';
import 'dart:convert';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';
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
    this.forcedVariations = const <String, int>{},
    this.client,
    this.gbFeatures = const {},
    this.onInitializationFailure,
    this.refreshHandler,
    this.stickyBucketService,
    this.backgroundSync,
    this.remoteEval = false,
  }) : assert(
          hostURL.endsWith('/'),
          'Invalid host url: $hostURL. The hostUrl should be end with `/`, example: `https://example.growthbook.io/`',
        );

  final String apiKey;
  final String hostURL;
  final bool enable;
  final bool qaMode;
  final Map<String, dynamic>? attributes;
  final Map<String, int> forcedVariations;
  final TrackingCallBack growthBookTrackingCallBack;
  final BaseClient? client;
  final GBFeatures gbFeatures;
  final OnInitializationFailure? onInitializationFailure;
  final bool? backgroundSync;
  final bool remoteEval;

  CacheRefreshHandler? refreshHandler;
  StickyBucketService? stickyBucketService;

  Future<GrowthBookSDK> initialize() async {
    final gbContext = GBContext(
      apiKey: apiKey,
      hostURL: hostURL,
      enabled: enable,
      qaMode: qaMode,
      attributes: attributes,
      forcedVariation: forcedVariations,
      trackingCallBack: growthBookTrackingCallBack,
      features: gbFeatures,
      stickyBucketService: stickyBucketService,
      backgroundSync: backgroundSync,
      remoteEval: remoteEval,
    );
    final gb = GrowthBookSDK._(
      context: gbContext,
      client: client,
      onInitializationFailure: onInitializationFailure,
      refreshHandler: refreshHandler,
      gbFeatures: gbFeatures,
    );
    await gb.refresh();
    await gb.refreshStickyBucketService(null);
    return gb;
  }

  GBSDKBuilderApp setRefreshHandler(CacheRefreshHandler refreshHandler) {
    this.refreshHandler = refreshHandler;
    return this;
  }

  GBSDKBuilderApp setStickyBucketService(
      StickyBucketService? stickyBucketService) {
    this.stickyBucketService = stickyBucketService;
    return this;
  }
}

/// The main export of the libraries is a simple GrowthBook wrapper class that
/// takes a Context object in the constructor.
/// It exposes two main methods: feature and run.
class GrowthBookSDK extends FeaturesFlowDelegate {
  GrowthBookSDK._({
    OnInitializationFailure? onInitializationFailure,
    required GBContext context,
    BaseClient? client,
    CacheRefreshHandler? refreshHandler,
    GBFeatures? gbFeatures,
  })  : _context = context,
        _onInitializationFailure = onInitializationFailure,
        _refreshHandler = refreshHandler,
        _gbFeatures = gbFeatures,
        _baseClient = client ?? DioClient(),
        _forcedFeatures = [],
        _attributeOverrides = {};

  final GBContext _context;

  final BaseClient _baseClient;

  final OnInitializationFailure? _onInitializationFailure;

  final CacheRefreshHandler? _refreshHandler;

  final GBFeatures? _gbFeatures;

  List<dynamic> _forcedFeatures;

  Map<String, dynamic> _attributeOverrides;

  /// The complete data regarding features & attributes etc.
  GBContext get context => _context;

  /// Retrieved features.
  dynamic get features => _context.features;

  @override
  void featuresFetchedSuccessfully({
    required GBFeatures gbFeatures,
    required bool isRemote,
  }) {
    _context.features = gbFeatures;
    _refreshHandler!(true);
  }

  @override
  void featuresFetchFailed({required GBError? error, required bool isRemote}) {
    _onInitializationFailure?.call(error);
    if (_refreshHandler != null) {
      _refreshHandler!(false);
    }
  }

  Future<void> refresh() async {
    final featureViewModel = FeatureViewModel(
      backgroundSync: _context.backgroundSync ?? false,
      encryptionKey: _context.encryptionKey ?? "",
      delegate: this,
      source: FeatureDataSource(
        client: _baseClient,
        context: _context,
      ),
    );
    if (_gbFeatures != null) {
      _context.features = _gbFeatures!;
    }
    if (_context.backgroundSync != false) {
      await featureViewModel.connectBackgroundSync();
    }
    if (_context.remoteEval) {
      refreshForRemoteEval();
    } else {
      await featureViewModel.fetchFeatures(context.getFeaturesURL());
    }
  }

  GBFeatureResult feature(String id) {
    return FeatureEvaluator(
      attributeOverrides: _attributeOverrides,
      context: context,
      featureKey: id,
    ).evaluateFeature();
  }

  GBExperimentResult run(GBExperiment experiment) {
    return ExperimentEvaluator(attributeOverrides: _attributeOverrides)
        .evaluateExperiment(context, experiment);
  }

  Map<StickyAttributeKey, StickyAssignmentsDocument>
      getStickyBucketAssignmentDocs() {
    return _context.stickyBucketAssignmentDocs ?? {};
  }

  /// Replaces the Map of user attributes that are used to assign variations
  void setAttributes(Map<String, dynamic> attributes) {
    _context.attributes = attributes;
    refreshStickyBucketService(null);
  }

  void setAttributeOverrides(dynamic overrides) {
    _attributeOverrides = json.decode(overrides);
    if (context.stickyBucketService != null) {
      refreshStickyBucketService(null);
    }
    refreshForRemoteEval();
  }

  /// The setForcedFeatures method updates forced features
  void setForcedFeatures(List<dynamic> forcedFeatures) {
    _forcedFeatures = forcedFeatures;
  }

  void setEncryptedFeatures(String encryptedString, String encryptionKey,
      [CryptoProtocol? subtle]) {
    CryptoProtocol crypto = subtle ?? Crypto();
    var features = crypto.getFeaturesFromEncryptedFeatures(
      encryptedString,
      encryptionKey,
    );

    if (features != null) {
      _context.features = features;
    }
  }

  void setForcedVariations(Map<String, dynamic> forcedVariations) {
    _context.forcedVariation = forcedVariations;
    refreshForRemoteEval();
  }

  @override
  void featuresAPIModelSuccessfully(FeaturedDataModel model) {
    refreshStickyBucketService(model);
  }

  Future<void> refreshStickyBucketService(FeaturedDataModel? data) async {
    if (context.stickyBucketService != null) {
      await GBUtils.refreshStickyBuckets(context, data, _attributeOverrides);
    }
  }

  Future<void> refreshForRemoteEval() async {
    if (!context.remoteEval) return;
    final featureViewModel = FeatureViewModel(
      backgroundSync: _context.backgroundSync ?? false,
      encryptionKey: _context.encryptionKey ?? "",
      delegate: this,
      source: FeatureDataSource(
        client: _baseClient,
        context: _context,
      ),
    );

    RemoteEvalModel payload = RemoteEvalModel(
      attributes: context.attributes,
      forcedFeatures: _forcedFeatures,
      forcedVariations: context.forcedVariation,
    );

    await featureViewModel.fetchFeatures(
      context.getRemoteEvalUrl(),
      remoteEval: context.remoteEval,
      payload: payload,
    );
  }
}
