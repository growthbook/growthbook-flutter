import 'dart:async';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';

typedef VoidCallback = void Function();

typedef OnInitializationFailure = void Function(GBError? error);

class GBSDKBuilderApp {
  GBSDKBuilderApp({
    required this.hostURL,
    required this.apiKey,
    this.sseUrl,
    required this.growthBookTrackingCallBack,
    this.attributes = const <String, dynamic>{},
    this.qaMode = false,
    this.enable = true,
    this.forcedVariations = const <String, int>{},
    this.client,
    this.gbFeatures = const {},
    this.onInitializationFailure,
    this.backgroundSync,
  }) : assert(
          hostURL.endsWith('/'),
          'Invalid host url: $hostURL. The hostUrl should be end with `/`, example: `https://example.growthbook.io/`',
        );

  final String apiKey;
  final String? sseUrl;
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

  Future<GrowthBookSDK> initialize() async {
    final gbContext = GBContext(
      apiKey: apiKey,
      sseUrl: sseUrl,
      hostURL: hostURL,
      enabled: enable,
      qaMode: qaMode,
      attributes: attributes,
      forcedVariation: forcedVariations,
      trackingCallBack: growthBookTrackingCallBack,
      features: gbFeatures,
      backgroundSync: backgroundSync,
    );
    final gb = GrowthBookSDK._(
      context: gbContext,
      client: client,
      onInitializationFailure: onInitializationFailure,
    );
    await gb.refresh();
    return gb;
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
  })  : _context = context,
        _onInitializationFailure = onInitializationFailure,
        _baseClient = client ?? DioClient();

  final GBContext _context;

  final BaseClient _baseClient;

  final OnInitializationFailure? _onInitializationFailure;

  /// The complete data regarding features & attributes etc.
  GBContext get context => _context;

  /// Retrieved features.
  GBFeatures get features => _context.features;

  @override
  void featuresFetchedSuccessfully(GBFeatures gbFeatures) {
    _context.features = gbFeatures;
  }

  @override
  void featuresFetchFailed(GBError? error) {
    _onInitializationFailure?.call(error);
  }

  Future<void> refresh() async {
    final featureViewModel = FeatureViewModel(
      backgroundSync: _context.backgroundSync ?? false,
      encryptionKey: _context.apiKey ?? "",
      delegate: this,
      source: FeatureDataSource(
        client: _baseClient,
        context: _context,
      ),
    );
    await featureViewModel.fetchFeature(context.sseUrl);
  }

  GBFeatureResult feature(String id) {
    return GBFeatureEvaluator.evaluateFeature(
      _context,
      id,
    );
  }

  GBExperimentResult run(GBExperiment experiment) {
    return GBExperimentEvaluator.evaluateExperiment(
      context: context,
      experiment: experiment,
    );
  }

  /// Replaces the Map of user attributes that are used to assign variations
  void setAttributes(Map<String, dynamic> attributes) {
    context.attributes = attributes;
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
}
