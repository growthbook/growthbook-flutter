import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';
import 'package:growthbook_sdk_flutter/src/Utils/feature_url_builder.dart';

import 'gb_features_converter.dart';

class FeatureViewModel {
  FeatureViewModel({
    required this.delegate,
    required this.source,
    required this.encryptionKey,
    this.backgroundSync,
    this.ttlSeconds = 60,
  });

  final FeaturesFlowDelegate delegate;
  final FeatureDataSource source;
  final String encryptionKey;
  final bool? backgroundSync;
  final int ttlSeconds;
  int? _expiresAt;

  final CachingManager manager = CachingManager();
  final utf8Encoder = const Utf8Encoder();
  final utf8Decoder = const Utf8Decoder();

  // Request coalescing - reuse ongoing fetch instead of creating new ones
  Future<FeaturedDataModel>? _ongoingFetch;

  Future<void> connectBackgroundSync() async {
    await source.fetchFeatures(
      featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS,
      (data) {
        prepareFeaturesData(data);
      },
      (e, s) => delegate.featuresFetchFailed(
        error: GBError(
          error: e,
          stackTrace: s.toString(),
        ),
        isRemote: true,
      ),
    );
  }

  Future<void> fetchFeatures(String? apiUrl,
      {bool remoteEval = false, RemoteEvalModel? payload}) async {
    final receivedData =
        await manager.getContent(fileName: Constant.featureCache);

    if (receivedData != null) {
      // Return cached data immediately
      final featureMap = _fetchCachedFeatures(receivedData);
      delegate.featuresFetchedSuccessfully(
        gbFeatures: featureMap,
        isRemote: false,
      );

      // If cache is expired, fetch fresh data
      if (isCacheExpired()) {
        await _fetchFreshData();
      }
    } else {
      // No cache, must fetch
      await _fetchFreshData();
    }

    // Handle remote eval if needed
    if (apiUrl != null && remoteEval) {
      await source.fetchRemoteEval(
        apiUrl: apiUrl,
        params: payload,
        onSuccess: (data) {
          prepareFeaturesData(data);
        },
        onError: (e, s) {
          delegate.featuresFetchFailed(
            error: GBError(
              error: e,
              stackTrace: s.toString(),
            ),
            isRemote: true,
          );
        },
      );
    }
  }

  Future<void> _fetchFreshData() async {
    // If there's already an ongoing fetch, wait for it
    if (_ongoingFetch != null) {
      log('Fetch already in progress, waiting for it to complete.');
      try {
        await _ongoingFetch!;
      } catch (e) {
        // Error already handled in the original fetch
        log('Ongoing fetch failed: $e');
      }
      return;
    }

    // Start new fetch
    _ongoingFetch = _performFetch();
    try {
      final data = await _ongoingFetch!;
      _handleSuccess(data);
    } catch (e, s) {
      delegate.featuresFetchFailed(
        error: GBError(
          error: e,
          stackTrace: s.toString(),
        ),
        isRemote: true,
      );
    } finally {
      _ongoingFetch = null;
    }
  }

  Future<FeaturedDataModel> _performFetch() async {
    final completer = Completer<FeaturedDataModel>();

    await source.fetchFeatures(
      (data) {
        if (!completer.isCompleted) {
          completer.complete(data);
        }
      },
      (e, s) {
        if (!completer.isCompleted) {
          completer.completeError(e, s);
        }
      },
    );

    return completer.future;
  }

  void _handleSuccess(FeaturedDataModel data) {
    delegate.featuresFetchedSuccessfully(
      gbFeatures: data.features!,
      isRemote: true,
    );
    cacheFeatures(data);
    refreshExpiresAt();
  }

  Map<String, GBFeature> _fetchCachedFeatures(Uint8List receivedData) {
    final receivedDataJson = utf8Decoder.convert(receivedData);
    final receiveFeatureJsonMap =
        jsonDecode(receivedDataJson) as Map<String, dynamic>;

    GBFeatures featureMap = {};
    if (encryptionKey.isNotEmpty) {
      // For encrypted features, parse directly as features map
      const converter = GBFeaturesConverter();
      featureMap = converter.fromJson(receiveFeatureJsonMap);
    } else {
      // For non-encrypted, use the full data model
      featureMap =
          FeaturedDataModel.fromJson(receiveFeatureJsonMap).features ?? {};
    }
    return featureMap;
  }

  void prepareFeaturesData(FeaturedDataModel data) {
    try {
      if (data.features == null && data.encryptedFeatures == null) {
        log("JSON is null.");
      } else {
        handleValidFeatures(data);
      }
    } catch (e, s) {
      handleException(e, s);
    }
  }

  void handleValidFeatures(FeaturedDataModel data) {
    if (data.features != null && data.encryptedFeatures == null) {
      delegate.featuresAPIModelSuccessfully(data);
      delegate.featuresFetchedSuccessfully(
          gbFeatures: data.features!, isRemote: true);
      final featureData = utf8Encoder.convert(jsonEncode(data));
      final featureDataOnUint8List = Uint8List.fromList(featureData);
      manager.putData(
        fileName: Constant.featureCache,
        content: featureDataOnUint8List,
      );

      if (data.savedGroups != null) {
        delegate.savedGroupsFetchedSuccessfully(
            savedGroups: data.savedGroups!, isRemote: true);
        final savedGroupsData =
            utf8Encoder.convert(jsonEncode(data.savedGroups));
        final savedGroupsDataOnUint8List = Uint8List.fromList(savedGroupsData);
        manager.putData(
          fileName: Constant.savedGroupsCache,
          content: savedGroupsDataOnUint8List,
        );
      }
    } else {
      if (data.encryptedFeatures != null) {
        handleEncryptedFeatures(data.encryptedFeatures!);
      }
      if (data.encryptedSavedGroups != null) {
        handleEncryptedSavedGroups(data.encryptedSavedGroups!);
      }
    }
  }

  void handleEncryptedFeatures(String encryptedFeatures) {
    if (encryptedFeatures.isEmpty) {
      logError("Failed to parse encrypted data.");
      return;
    }

    if (encryptionKey.isEmpty) {
      logError("Encryption key is missing.");
      return;
    }

    try {
      final crypto = Crypto();
      final extractedFeatures = crypto.getFeaturesFromEncryptedFeatures(
        encryptedFeatures,
        encryptionKey,
      );

      if (extractedFeatures != null) {
        delegate.featuresFetchedSuccessfully(
            gbFeatures: extractedFeatures, isRemote: true);
        final featureData = utf8Encoder.convert(jsonEncode(extractedFeatures));
        final featureDataOnUint8List = Uint8List.fromList(featureData);
        manager.putData(
          fileName: Constant.featureCache,
          content: featureDataOnUint8List,
        );
      } else {
        logError("Failed to extract features from encrypted string.");
      }
    } catch (e, s) {
      delegate.featuresFetchFailed(
        error: GBError(
          error: e,
          stackTrace: s.toString(),
        ),
        isRemote: true,
      );
    }
  }

  void handleEncryptedSavedGroups(String encryptedSavedGroups) {
    if (encryptedSavedGroups.isEmpty) {
      logError("Failed to parse encrypted data.");
      return;
    }

    if (encryptionKey.isEmpty) {
      logError("Encryption key is missing.");
      return;
    }

    try {
      final crypto = Crypto();
      final extractedSavedGroups = crypto.getSavedGroupsFromEncryptedFeatures(
        encryptedSavedGroups,
        encryptionKey,
      );

      if (extractedSavedGroups != null) {
        delegate.savedGroupsFetchedSuccessfully(
            savedGroups: extractedSavedGroups, isRemote: false);
        final savedGroupsData =
            utf8Encoder.convert(jsonEncode(extractedSavedGroups));
        final savedGroupsDataOnUint8List = Uint8List.fromList(savedGroupsData);
        manager.putData(
          fileName: Constant.savedGroupsCache,
          content: savedGroupsDataOnUint8List,
        );
      } else {
        logError("Failed to extract savedGroups from encrypted string.");
      }
    } catch (e, s) {
      delegate.savedGroupsFetchFailed(
        error: GBError(
          error: e,
          stackTrace: s.toString(),
        ),
        isRemote: false,
      );
    }
  }

  void handleException(dynamic e, dynamic s) {
    delegate.featuresFetchFailed(
      error: GBError(
        error: e,
        stackTrace: s.toString(),
      ),
      isRemote: false,
    );
  }

  void logError(String message) {
    log("Failed to parse data. $message");
  }

  void cacheFeatures(FeaturedDataModel data) {
    final featureData = utf8Encoder.convert(jsonEncode(data));
    final featureDataOnUint8List = Uint8List.fromList(featureData);
    manager.putData(
      fileName: Constant.featureCache,
      content: featureDataOnUint8List,
    );
  }

  void refreshExpiresAt() {
    _expiresAt = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + ttlSeconds;
  }

  bool isCacheExpired() {
    if (_expiresAt == null) {
      return true;
    } else {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return now >= _expiresAt!;
    }
  }
}
