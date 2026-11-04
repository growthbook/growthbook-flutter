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

  /// Round currently running, completed with that round's own outcome so every
  /// caller joining it gets the result of the round it actually waited for.
  Completer<bool>? _ongoingFetch;

  /// Whether the round in [_ongoingFetch] bypasses the cache.
  bool _ongoingFetchForced = false;

  Future<void> connectBackgroundSync() async {
    await source.fetchFeatures(
      featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS,
      (data) async {
        await prepareFeaturesData(data);
      },
      (e, s) => delegate.featuresFetchFailed(
        error: GBError(error: e, stackTrace: s.toString()),
        isRemote: true,
      ),
    );
  }

  /// Loads features, from cache when it can and from the network when it must.
  ///
  /// Returns whether the round ended with usable definitions: false only when a
  /// network round failed. A caller driving its own schedule - the polling loop -
  /// needs its own outcome, which the delegate cannot give it because the same
  /// callbacks serve initialization, streaming and manual refreshes.
  ///
  /// [force] skips the cache entirely so the round always reaches the network.
  /// Without it a caller polling faster than [ttlSeconds] would issue no
  /// requests at all. A forced call that arrives while an unforced round is in
  /// flight waits for it and then runs its own, rather than reporting a round
  /// that may never have left the device.
  Future<bool> fetchFeatures(String? apiUrl,
      {bool remoteEval = false,
      RemoteEvalModel? payload,
      bool force = false}) async {
    // If there's already an ongoing request — wait for it to complete
    while (_ongoingFetch != null) {
      final ongoing = _ongoingFetch!;
      final ongoingWasForced = _ongoingFetchForced;
      log('Fetch already in progress, waiting for completion.');
      final outcome = await ongoing.future;
      // A forced caller cannot take the answer of an unforced round: that round
      // may have been served from a fresh cache without ever reaching the
      // network, which is the one thing force rules out. Run its own round
      // instead - after the loop, since yet another may have started meanwhile.
      if (!force || ongoingWasForced) return outcome;
    }

    final completer = Completer<bool>();
    _ongoingFetch = completer;
    _ongoingFetchForced = force;

    bool succeeded;
    try {
      succeeded = await _runRound(apiUrl,
          remoteEval: remoteEval, payload: payload, force: force);
    } catch (e, s) {
      succeeded = false;
      delegate.featuresFetchFailed(
        error: GBError(error: e, stackTrace: s.toString()),
        isRemote: true,
      );
    } finally {
      _ongoingFetch = null;
    }
    // After the round is off the field, so a waiter resuming here never joins
    // one that has already finished.
    completer.complete(succeeded);
    return succeeded;
  }

  Future<bool> _runRound(String? apiUrl,
      {required bool remoteEval,
      required RemoteEvalModel? payload,
      required bool force}) async {
    // A forced round reaches the network whatever the cache holds, and the
    // in-memory features already mirror the cache, so reading it would only
    // decode the same JSON and rebuild the evaluation context a second time.
    final cached = force
        ? null
        : await manager.getContent(fileName: Constant.featureCache);
    final featureMap = cached != null ? _fetchCachedFeatures(cached) : null;

    if (featureMap != null) {
      delegate.featuresFetchedSuccessfully(
        gbFeatures: featureMap,
        isRemote: false,
      );
    }

    if (remoteEval && apiUrl != null) {
      return _fetchRemoteEval(apiUrl, payload);
    }

    // If cache is missing, corrupt, or expired, fetch fresh data from network
    if (force || featureMap == null || isCacheExpired()) {
      // A 304 only follows an ETag this process stored from an earlier 200, so
      // on a forced round there is always a cached payload for it to confirm.
      return _fetchFromNetwork(hasCachedFeatures: force || featureMap != null);
    }
    return true;
  }

  Future<bool> _fetchFromNetwork({bool hasCachedFeatures = false}) async {
    // null = no callback invoked (304 Not Modified), true = success, false = error
    bool? success;
    try {
      await source.fetchFeatures(
        (data) async {
          success = await _handleSuccess(data);
        },
        (e, s) {
          success = false;
          delegate.featuresFetchFailed(
            error: GBError(error: e, stackTrace: s.toString()),
            isRemote: true,
          );
        },
      );
    } catch (e) {
      success = false;
    }
    // Refresh TTL on success or 304 Not Modified (null means server confirmed cache is still valid)
    if (success != false) {
      refreshExpiresAt();
    }
    // Only notify delegate of 304 if there was a valid cached payload to confirm.
    // Without an existing cache, 304 is meaningless — callers must not treat it as success.
    if (success == null && hasCachedFeatures) {
      delegate.featuresNotModified();
    }
    return success != false;
  }

  Future<bool> _fetchRemoteEval(String apiUrl, RemoteEvalModel? payload) async {
    bool success = false;
    try {
      await source.fetchRemoteEval(
        apiUrl: apiUrl,
        params: payload,
        onSuccess: (data) async {
          success = await prepareFeaturesData(data);
        },
        onError: (e, s) {
          success = false;
          log('Remote Eval Error: $e');
          delegate.featuresFetchFailed(
            error: GBError(error: e, stackTrace: s.toString()),
            isRemote: true,
          );
        },
      );
    } catch (e) {
      // Both failure paths land here or leave success false: an unparseable
      // payload and a throwing request alike. Reporting the round as a success
      // would reset the caller's failure count and keep the backoff from ever
      // starting.
      success = false;
    }
    if (success) {
      refreshExpiresAt();
    }
    return success;
  }

  Future<bool> _handleSuccess(FeaturedDataModel data) async {
    // Use prepareFeaturesData to handle both encrypted and non-encrypted responses.
    // When encryption is enabled, the API returns data.encryptedFeatures (not data.features).
    return await prepareFeaturesData(data);
  }

  Map<String, GBFeature>? _fetchCachedFeatures(Uint8List receivedData) {
    if (receivedData.isEmpty) return null;

    try {
      final receivedDataJson = utf8Decoder.convert(receivedData);
      if (receivedDataJson.trim().isEmpty) return null;

      final receiveFeatureJsonMap =
          jsonDecode(receivedDataJson) as Map<String, dynamic>;

      if (encryptionKey.isNotEmpty) {
        const converter = GBFeaturesConverter();
        return converter.fromJson(receiveFeatureJsonMap);
      } else {
        return FeaturedDataModel.fromJson(receiveFeatureJsonMap).features ?? {};
      }
    } catch (e, s) {
      log('Failed to parse cached features, clearing corrupt cache: $e');
      manager.removeContent(fileName: Constant.featureCache);
      handleException(e, s);
      return null;
    }
  }

  Future<bool> prepareFeaturesData(FeaturedDataModel data) async {
    try {
      // If both features and encryptedFeatures are null, log JSON as null
      if (data.features == null && data.encryptedFeatures == null) {
        log("JSON is null.");
        return false;
      } else {
        return await handleValidFeatures(data);
      }
    } catch (e, s) {
      handleException(e, s);
      return false;
    }
  }

  Future<bool> handleValidFeatures(FeaturedDataModel data) async {
    if (data.features != null && data.encryptedFeatures == null) {
      // Handle non-encrypted features
      await delegate.featuresAPIModelSuccessfully(data);
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
      return true;
    } else {
      // Handle encrypted features/savedGroups if available
      var isHandleEncryptedFeatures = false;
      var isHandleEncryptedSavedGroups = true;

      if (data.encryptedFeatures != null) {
        isHandleEncryptedFeatures =
            handleEncryptedFeatures(data.encryptedFeatures!);
      }

      if (data.encryptedSavedGroups != null) {
        isHandleEncryptedSavedGroups =
            handleEncryptedSavedGroups(data.encryptedSavedGroups!);
      }
      return isHandleEncryptedFeatures && isHandleEncryptedSavedGroups;
    }
  }

  bool handleEncryptedFeatures(String encryptedFeatures) {
    if (encryptedFeatures.isEmpty) {
      logError("Failed to parse encrypted data.");
      return false;
    }

    if (encryptionKey.isEmpty) {
      logError("Encryption key is missing.");
      return false;
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
        return true;
      } else {
        logError("Failed to extract features from encrypted string.");
        return false;
      }
    } catch (e, s) {
      delegate.featuresFetchFailed(
        error: GBError(error: e, stackTrace: s.toString()),
        isRemote: true,
      );
      return false;
    }
  }

  bool handleEncryptedSavedGroups(String encryptedSavedGroups) {
    if (encryptedSavedGroups.isEmpty) {
      logError("Failed to parse encrypted data.");
      return false;
    }

    if (encryptionKey.isEmpty) {
      logError("Encryption key is missing.");
      return false;
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
        return true;
      } else {
        logError("Failed to extract savedGroups from encrypted string.");
        return false;
      }
    } catch (e, s) {
      delegate.savedGroupsFetchFailed(
        error: GBError(error: e, stackTrace: s.toString()),
        isRemote: false,
      );
      return false;
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
    final result = now >= _expiresAt!;
    return result;
  }
}
