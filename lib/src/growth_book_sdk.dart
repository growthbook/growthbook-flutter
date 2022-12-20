import 'dart:async';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

typedef VoidCallback = void Function();

abstract class SDKBuilder {
  SDKBuilder({
    required this.apiKey,
    required this.hostURL,
    this.attributes = const <String, dynamic>{},
    required this.growthBookTrackingCallBack,
  })  : qaMode = false,
        forcedVariations = <String, int>{},
        enable = true;

  final String apiKey;
  final String hostURL;
  Map<String, dynamic>? attributes;
  final TrackingCallBack growthBookTrackingCallBack;

  bool qaMode;

  bool enable;

  Map<String, int> forcedVariations;

  ///  Set Forced Variations - Default Empty
  SDKBuilder setForcedVariations(Map<String, int> forcedVariations) {
    this.forcedVariations = forcedVariations;
    return this;
  }

  /// Set Enabled - Default Disabled - If Enabled - then experiments will be disabled
  SDKBuilder setQAMode(bool value) {
    qaMode = value;
    return this;
  }

  GrowthBookSDK initialize();
}

class GBSDKBuilderApp extends SDKBuilder {
  GBSDKBuilderApp({
    required super.apiKey,
    required super.hostURL,
    super.attributes = const <String, dynamic>{},
    required super.growthBookTrackingCallBack,
  }) {
    customLogger('GrowthBook initialized successfully.');
  }

  BaseClient? _client;

  @override
  GrowthBookSDK initialize() {
    final gbContext = GBContext(
      apiKey: apiKey,
      hostURL: hostURL,
      enabled: enable,
      attributes: attributes,
      qaMode: qaMode,
      forcedVariation: forcedVariations,
      trackingCallBack: growthBookTrackingCallBack,
    );
    return GrowthBookSDK(context: gbContext, client: _client);
  }

  ///   Set Network Client - Network Client for Making API Calls
  SDKBuilder setNetworkDispatcher(BaseClient client) {
    _client = client;
    return this;
  }
}

/// The main export of the libraries is a simple GrowthBook wrapper class that
/// takes a Context object in the constructor.
/// It exposes two main methods: feature and run.
/// It also includes stream of [StateHelper] which can be utilized in case
/// sdk is not loaded yet and we want to show some in place.
class GrowthBookSDK extends FeaturesFlowDelegate {
  GrowthBookSDK(
      {required GBContext context,
      GBFeatures? features,
      BaseClient? client,
      VoidCallback? afterFetch})
      : _context = context,
        _sdkStreamController = StreamController<StateHelper>(),
        _baseClient = client ?? DioClient() {
    if (features != null) {
      _context.features = features;
    }
    _sdkStreamController.sink.add(StateHelper.loading);
    refresh();
  }
  final StreamController<StateHelper> _sdkStreamController;

  VoidCallback? afterFetch;

  ///
  final GBContext _context;

  GBContext get context => _context;

  GBFeatures get features => _context.features;

  Stream<StateHelper> get stream =>
      _sdkStreamController.stream.asBroadcastStream();

  final BaseClient _baseClient;

  @override
  void featuresFetchedSuccessfully(GBFeatures gbFeatures) {
    _context.features = gbFeatures;
    if (afterFetch != null) {
      afterFetch!.call();
    }
    _sdkStreamController.sink.add(StateHelper.fetched);
  }

  Future<void> refresh() async {
    final featureViewModel = FeatureViewModel(
      delegate: this,
      source: FeatureDataSource(
          client: _baseClient,
          context: _context,
          onError: (e, s) {
            _sdkStreamController.sink.add(StateHelper.error);
          }),
    );
    await featureViewModel.fetchFeature();
  }

  GBFeatureResult feature(String id) {
    return GBFeatureEvaluator().evaluateFeature(_context, id);
  }
}
