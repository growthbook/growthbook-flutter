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

  Completer<void>? _ongoingFetch;

  Future<void> connectBackgroundSync() async {
    await source.fetchFeatures(
      featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS,
      (data) {
        prepareFeaturesData(data);
      },
      (e, s) => delegate.featuresFetchFailed(
        error: GBError(error: e, stackTrace: s.toString()),
        isRemote: true,
      ),
    );
  }

  Future<void> fetchFeatures(String? apiUrl,
      {bool remoteEval = false, RemoteEvalModel? payload}) async {
    // If there's already an ongoing request — wait for it to complete
    if (_ongoingFetch != null) {
      log('Fetch already in progress, waiting for completion.');
      return _ongoingFetch!.future;
    }

    final completer = Completer<void>();
    _ongoingFetch = completer;

    try {
      if (remoteEval && apiUrl != null) {
        final receivedData =
            await manager.getContent(fileName: Constant.featureCache);

        if (receivedData != null) {
          final featureMap = _fetchCachedFeatures(receivedData);
          delegate.featuresFetchedSuccessfully(
            gbFeatures: featureMap,
            isRemote: false,
          );
        }

        await _fetchRemoteEval(apiUrl, payload);
      } else {
        final receivedData =
            await manager.getContent(fileName: Constant.featureCache);

        if (receivedData != null) {
          final featureMap = _fetchCachedFeatures(receivedData);
          delegate.featuresFetchedSuccessfully(
            gbFeatures: featureMap,
            isRemote: false,
          );

          // If cache is expired, fetch fresh data from network
          if (isCacheExpired()) {
            await _fetchFromNetwork();
          }
        } else {
          // No cache available, fetch from network
          await _fetchFromNetwork();
        }
      }

      completer.complete();
    } catch (e, s) {
      completer.completeError(e, s);
      delegate.featuresFetchFailed(
        error: GBError(error: e, stackTrace: s.toString()),
        isRemote: true,
      );
    } finally {
      _ongoingFetch = null;
    }
  }

  Future<void> _fetchFromNetwork() async {
    await source.fetchFeatures(
      (data) => _handleSuccess(data),
      (e, s) => delegate.featuresFetchFailed(
        error: GBError(error: e, stackTrace: s.toString()),
        isRemote: true,
      ),
    );
  }

  Future<void> _fetchRemoteEval(String apiUrl, RemoteEvalModel? payload) async {
    await source.fetchRemoteEval(
      apiUrl: apiUrl,
      params: payload,
      onSuccess: (data) => {prepareFeaturesData(data), refreshExpiresAt()},
      onError: (e, s) => {
        log('Remote Eval Error: $e'),
        delegate.featuresFetchFailed(
          error: GBError(error: e, stackTrace: s.toString()),
          isRemote: true,
        )
      },
    );
  }

  void _handleSuccess(FeaturedDataModel data) {
    // Use prepareFeaturesData to handle both encrypted and non-encrypted responses.
    // When encryption is enabled, the API returns data.encryptedFeatures (not data.features).
    prepareFeaturesData(data);
    refreshExpiresAt();
  }

  Map<String, GBFeature> _fetchCachedFeatures(Uint8List receivedData) {
    final receivedDataJson = utf8Decoder.convert(receivedData);
    final receiveFeatureJsonMap =
        jsonDecode(receivedDataJson) as Map<String, dynamic>;

    if (encryptionKey.isNotEmpty) {
      const converter = GBFeaturesConverter();
      return converter.fromJson(receiveFeatureJsonMap);
    } else {
      return FeaturedDataModel.fromJson(receiveFeatureJsonMap).features ?? {};
    }
  }

  void prepareFeaturesData(FeaturedDataModel data) {
    try {
      // If both features and encryptedFeatures are null, log JSON as null
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
      // Handle non-encrypted features
      delegate.featuresAPIModelSuccessfully(data);
      delegate.featuresFetchedSuccessfully(
        gbFeatures: data.features!,
        isRemote: true,
      );
      final featureData = utf8Encoder.convert(jsonEncode(data));
      manager.putData(
        fileName: Constant.featureCache,
        content: Uint8List.fromList(featureData),
      );

      if (data.savedGroups != null) {
        // Handle saved groups
        delegate.savedGroupsFetchedSuccessfully(
          savedGroups: data.savedGroups!,
          isRemote: true,
        );
        final savedGroupsData =
            utf8Encoder.convert(jsonEncode(data.savedGroups));
        manager.putData(
          fileName: Constant.savedGroupsCache,
          content: Uint8List.fromList(savedGroupsData),
        );
      }
    } else {
      // Handle encrypted features/savedGroups if available
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
        manager.putData(
          fileName: Constant.featureCache,
          content: Uint8List.fromList(featureData),
        );
      } else {
        logError("Failed to extract features from encrypted string.");
      }
    } catch (e, s) {
      delegate.featuresFetchFailed(
        error: GBError(error: e, stackTrace: s.toString()),
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
            savedGroups: extractedSavedGroups, isRemote: true);
        final savedGroupsData =
            utf8Encoder.convert(jsonEncode(extractedSavedGroups));
        manager.putData(
          fileName: Constant.savedGroupsCache,
          content: Uint8List.fromList(savedGroupsData),
        );
      } else {
        logError("Failed to extract savedGroups from encrypted string.");
      }
    } catch (e, s) {
      delegate.savedGroupsFetchFailed(
        error: GBError(error: e, stackTrace: s.toString()),
        isRemote: false,
      );
    }
  }

  void handleException(dynamic e, dynamic s) {
    delegate.featuresFetchFailed(
      error: GBError(error: e, stackTrace: s.toString()),
      isRemote: false,
    );
  }

  void logError(String message) {
    log("Failed to parse data. $message");
  }

  void cacheFeatures(FeaturedDataModel data) {
    final featureData = utf8Encoder.convert(jsonEncode(data));
    manager.putData(
      fileName: Constant.featureCache,
      content: Uint8List.fromList(featureData),
    );
  }

  void refreshExpiresAt() {
    _expiresAt = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + ttlSeconds;
  }

  bool isCacheExpired() {
    if (_expiresAt == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= _expiresAt!;
  }
}
