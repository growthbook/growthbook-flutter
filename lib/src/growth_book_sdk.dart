import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';

typedef VoidCallback = void Function();

typedef OnInitializationFailure = void Function(GBError? error);

class GBSDKBuilderApp {
  GBSDKBuilderApp({
    required this.hostURL,
    required this.apiKey,
    this.encryptionKey,
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
    this.backgroundSync = false,
    this.remoteEval = false,
  });

  final String apiKey;
  final String? encryptionKey;
  final String hostURL;
  final bool enable;
  final bool qaMode;
  final Map<String, dynamic>? attributes;
  final Map<String, int> forcedVariations;
  final TrackingCallBack growthBookTrackingCallBack;
  final BaseClient? client;
  final GBFeatures gbFeatures;
  final OnInitializationFailure? onInitializationFailure;
  final bool backgroundSync;
  final bool remoteEval;

  CacheRefreshHandler? refreshHandler;
  StickyBucketService? stickyBucketService;
  GBFeatureUsageCallback? featureUsageCallback;

  Future<GrowthBookSDK> initialize() async {
    final gbContext = GBContext(
      apiKey: apiKey,
      encryptionKey: encryptionKey,
      hostURL: hostURL,
      enabled: enable,
      qaMode: qaMode,
      attributes: attributes,
      forcedVariation: forcedVariations,
      trackingCallBack: growthBookTrackingCallBack,
      featureUsageCallback: featureUsageCallback,
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

  GBSDKBuilderApp setStickyBucketService(StickyBucketService? stickyBucketService) {
    this.stickyBucketService = stickyBucketService;
    return this;
  }

  /// Setter for featureUsageCallback. A callback that will be invoked every time a feature is viewed.
  GBSDKBuilderApp setFeatureUsageCallback(GBFeatureUsageCallback featureUsageCallback) {
    this.featureUsageCallback = featureUsageCallback;
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
    EvaluationContext? evaluationContext,
    BaseClient? client,
    CacheRefreshHandler? refreshHandler,
    GBFeatures? gbFeatures,
    SavedGroupsValues? savedGroups,
  })  : _context = context,
        _evaluationContext = evaluationContext,
        _onInitializationFailure = onInitializationFailure,
        _refreshHandler = refreshHandler,
        _gbFeatures = gbFeatures,
        _savedGroups = savedGroups,
        _baseClient = client ?? DioClient(),
        _forcedFeatures = [],
        _attributeOverrides = {};

  final GBContext _context;

  final EvaluationContext? _evaluationContext;

  final BaseClient _baseClient;

  final OnInitializationFailure? _onInitializationFailure;

  final CacheRefreshHandler? _refreshHandler;

  final GBFeatures? _gbFeatures;

  final SavedGroupsValues? _savedGroups;

  List<dynamic> _forcedFeatures;

  Map<String, dynamic> _attributeOverrides;

  List<ExperimentRunCallback> subscriptions = [];

  Map<String, AssignedExperiment> assigned = {};

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
    if (isRemote) {
      if (_refreshHandler != null) {
        _refreshHandler!(true);
      }
    }
  }

  @override
  void featuresFetchFailed({required GBError? error, required bool isRemote}) {
    _onInitializationFailure?.call(error);
    if (isRemote) {
      if (_refreshHandler != null) {
        _refreshHandler!(false);
      }
    }
  }

  Future<void> autoRefresh() async {
    final featureViewModel = FeatureViewModel(
      backgroundSync: _context.backgroundSync,
      encryptionKey: _context.encryptionKey ?? "",
      delegate: this,
      source: FeatureDataSource(
        client: _baseClient,
        context: _context,
      ),
    );
    if (_context.backgroundSync) {
      await featureViewModel.connectBackgroundSync();
    }
  }

  Future<void> refresh() async {
    final featureViewModel = FeatureViewModel(
      backgroundSync: _context.backgroundSync,
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
    if (_savedGroups != null) {
      _context.savedGroups = _savedGroups!;
    }
    if (_context.remoteEval) {
      refreshForRemoteEval();
    } else {
      log(context.getFeaturesURL().toString());
      await featureViewModel.fetchFeatures(context.getFeaturesURL());
    }
  }

  void fireSubscriptions(GBExperiment experiment, GBExperimentResult result) {
    String key = experiment.key;

    // If assigned variation has changed, fire subscriptions
    if (assigned.containsKey(key)) {
      var assignedExperiment = assigned[key];

      if (assignedExperiment!.experimentResult.inExperiment != result.inExperiment ||
          assignedExperiment.experimentResult.variationID != result.variationID) {
        updateSubscriptions(key: key, experiment: experiment, result: result);
      }
    }
  }

  void updateSubscriptions(
      {required String key, required GBExperiment experiment, required GBExperimentResult result}) {
    assigned[key] = AssignedExperiment(experiment: experiment, experimentResult: result);
    for (var subscription in subscriptions) {
      subscription(experiment, result);
    }
  }

  void subscribe(ExperimentRunCallback callback) {
    subscriptions.add(callback);
  }

  void clearSubscriptions() {
    subscriptions.clear();
  }

  GBFeatureResult feature(String id) {
    return FeatureEvaluator().evaluateFeature(GBUtils.initializeEvalContext(context, _refreshHandler), id);
  }

  GBExperimentResult run(GBExperiment experiment) {
    final result = ExperimentEvaluator().evaluateExperiment(
      GBUtils.initializeEvalContext(context, _refreshHandler),
      experiment,
    );
    return result;
  }

  Map<StickyAttributeKey, StickyAssignmentsDocument> getStickyBucketAssignmentDocs() {
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

  void setEncryptedFeatures(String encryptedString, String encryptionKey, [CryptoProtocol? subtle]) {
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
      await GBUtils.refreshStickyBuckets(_evaluationContext!, data, _evaluationContext!.userContext.attributes ?? {});
    }
  }

  Future<void> refreshForRemoteEval() async {
    if (!context.remoteEval) return;
    final featureViewModel = FeatureViewModel(
      backgroundSync: _context.backgroundSync,
      encryptionKey: _context.encryptionKey ?? "",
      delegate: this,
      source: FeatureDataSource(
        client: _baseClient,
        context: _context,
      ),
    );

    RemoteEvalModel payload = RemoteEvalModel(
      attributes: _evaluationContext?.userContext.attributes ?? {},
      forcedFeatures: _forcedFeatures,
      forcedVariations: _evaluationContext?.userContext.forcedVariationsMap ?? {},
    );

    await featureViewModel.fetchFeatures(
      context.getRemoteEvalUrl(),
      remoteEval: context.remoteEval,
      payload: payload,
    );
  }

  /// The evalFeature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.
  GBFeatureResult evalFeature(String id) {
    return FeatureEvaluator().evaluateFeature(GBUtils.initializeEvalContext(context, _refreshHandler), id);
  }

  /// The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off
  bool isOn(String id) {
    return evalFeature(id).on;
  }

  @override
  void savedGroupsFetchFailed({required GBError? error, required bool isRemote}) {
    _onInitializationFailure?.call(error);
    if (isRemote) {
      if (_refreshHandler != null) {
        _refreshHandler!(false);
      }
    }
  }

  @override
  void savedGroupsFetchedSuccessfully({required SavedGroupsValues savedGroups, required bool isRemote}) {
    _context.savedGroups = savedGroups;
    if (isRemote) {
      if (_refreshHandler != null) {
        _refreshHandler!(true);
      }
    }
  }
}
