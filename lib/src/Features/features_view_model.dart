import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';
import 'package:growthbook_sdk_flutter/src/Utils/log_redaction.dart';
import 'package:growthbook_sdk_flutter/src/Utils/feature_url_builder.dart';

import 'gb_features_converter.dart';

class FeatureViewModel {
  FeatureViewModel({
    required this.delegate,
    required this.source,
    required this.encryptionKey,
    this.backgroundSync,
    this.ttlSeconds = 60,
    this.remoteEvalRequestProvider,
  });

  final FeaturesFlowDelegate delegate;
  final FeatureDataSource source;
  final String encryptionKey;
  final bool? backgroundSync;
  final int ttlSeconds;

  /// Builds the payload for the next remote-evaluation round. Supplying it makes
  /// this view model run in remote-eval mode: every network round is a POST
  /// carrying the current evaluation inputs instead of a plain GET.
  ///
  /// It is a provider rather than a value so a round started later (a refresh
  /// after an attribute change, a streamed update) sends the state as it is at
  /// that moment, not as it was when the view model was created.
  final RemoteEvalRequestProvider? remoteEvalRequestProvider;

  /// Whether features are evaluated remotely. Mirrors the reference JS SDK,
  /// where `fetchFeatures()` branches on `isRemoteEval()` — a plain GET must
  /// never serve a remote-eval SDK, or it would surface unevaluated features.
  bool get isRemoteEval => remoteEvalRequestProvider != null;

  /// Name of the cache entry holding the features payload.
  ///
  /// Namespaced per SDK connection: two instances configured with different
  /// client keys or hosts serve different payloads, and a single shared name
  /// makes each one overwrite and then read back the other's payload.
  String get featureCacheFileName => _namespaced(Constant.featureCache);

  /// Name of the cache entry holding the saved groups, namespaced the same way
  /// as [featureCacheFileName].
  String get savedGroupsCacheFileName => _namespaced(Constant.savedGroupsCache);

  /// Appends a short digest of the connection this view model fetches for.
  ///
  /// The digest is hashed rather than spelled out because the cache lives in the
  /// system temp directory, which on desktop platforms other processes can read —
  /// the client key does not belong in a path there.
  String _namespaced(String name) {
    final connection = '${source.context.apiKey}|${source.context.hostURL}';
    final digest = FNV().fnv1a32(connection).toRadixString(16);
    return '${name}_$digest';
  }

  int? _expiresAt;

  final CachingManager manager = CachingManager();
  final utf8Encoder = const Utf8Encoder();
  final utf8Decoder = const Utf8Decoder();

  Completer<void>? _ongoingFetch;

  /// Whether the cached payload has already been served in remote-eval mode.
  /// See the cold-start note in [fetchFeatures].
  bool _servedRemoteEvalCache = false;

  /// Bumped when a remote-eval round starts. Rounds run independently and are
  /// never cancelled, so a slower older POST can answer after a newer one; a
  /// response is only applied while its round is still the latest.
  int _remoteEvalGeneration = 0;

  Future<void> connectBackgroundSync() async {
    await source.fetchFeatures(
      featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS,
      (data) async {
        if (isRemoteEval) {
          // Streamed payloads are the same unevaluated features a GET returns.
          // Applying them in remote-eval mode would replace the personalized
          // features with generic ones, so the event is only a signal that
          // something changed: re-evaluate remotely instead.
          await _fetchRemoteEval();
          return;
        }
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
  /// In remote-eval mode the network round is a POST built from
  /// [remoteEvalRequestProvider] and [apiUrl] is ignored.
  Future<void> fetchFeatures(String? apiUrl) async {
    if (isRemoteEval) {
      // A remote-eval round is specific to the evaluation inputs it carries, so
      // it never joins a round that is already in flight: joining would drop the
      // change that triggered this call (new attributes, new forced values) and
      // leave the SDK evaluating a response built for the previous state. Rounds
      // may therefore overlap; _fetchRemoteEval discards superseded responses.
      if (!_servedRemoteEvalCache) {
        // Cached features were evaluated for whatever inputs the previous round
        // used, so they are only worth showing before the first round of this
        // session — never as an answer to a state change.
        _servedRemoteEvalCache = true;
        await _serveCachedFeatures();
      }
      await _fetchRemoteEval();
      return;
    }

    // If there's already an ongoing request — wait for it to complete
    if (_ongoingFetch != null) {
      log('Fetch already in progress, waiting for completion.');
      return _ongoingFetch!.future;
    }

    final completer = Completer<void>();
    _ongoingFetch = completer;

    try {
      final receivedData =
          await manager.getContent(fileName: featureCacheFileName);

      final featureMap =
          receivedData != null ? _fetchCachedFeatures(receivedData) : null;

      if (featureMap != null) {
        delegate.featuresFetchedSuccessfully(
          gbFeatures: featureMap,
          isRemote: false,
        );
      }

      // If cache is missing, corrupt, or expired, fetch fresh data from network
      if (featureMap == null || isCacheExpired()) {
        await _fetchFromNetwork(hasCachedFeatures: featureMap != null);
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

  Future<void> _fetchFromNetwork({bool hasCachedFeatures = false}) async {
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
  }

  /// Serves the cached payload to the delegate, if there is a usable one.
  Future<void> _serveCachedFeatures() async {
    final receivedData =
        await manager.getContent(fileName: featureCacheFileName);
    if (receivedData == null) return;

    final featureMap = _fetchCachedFeatures(receivedData);
    if (featureMap == null) return;

    delegate.featuresFetchedSuccessfully(
      gbFeatures: featureMap,
      isRemote: false,
    );
  }

  Future<void> _fetchRemoteEval() async {
    final request = remoteEvalRequestProvider?.call();
    if (request == null) return;

    // Tags this round. A response is applied and reported only while no newer
    // round has started, so a slow evaluation of the previous attributes cannot
    // overwrite the evaluation of the current ones.
    final generation = ++_remoteEvalGeneration;
    bool isSuperseded() => generation != _remoteEvalGeneration;

    bool success = false;
    // Set once the failure has been reported, so a client that both invokes
    // onError and throws does not report the same round twice.
    bool reportedFailure = false;
    try {
      await source.fetchRemoteEval(
        apiUrl: request.apiUrl,
        params: request.payload,
        onSuccess: (data) async {
          if (isSuperseded()) return;
          success = await prepareFeaturesData(data);
        },
        onError: (e, s) {
          success = false;
          if (isSuperseded()) return;
          reportedFailure = true;
          log('Remote eval request failed: ${describeRequestError(e)}');
          delegate.featuresFetchFailed(
            error: GBError(error: e, stackTrace: s.toString()),
            isRemote: true,
          );
        },
      );
    } catch (e, s) {
      // A client that throws while sending (instead of calling onError) must
      // still surface as a fetch failure rather than being swallowed.
      success = false;
      if (!reportedFailure && !isSuperseded()) {
        delegate.featuresFetchFailed(
          error: GBError(error: e, stackTrace: s.toString()),
          isRemote: true,
        );
      }
    }
    if (success) {
      refreshExpiresAt();
    }
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
      // Only the error type: a FormatException stringifies with the offending
      // payload attached.
      log('Failed to parse cached features, clearing corrupt cache: '
          '${e.runtimeType}');
      manager.removeContent(fileName: featureCacheFileName);
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
        fileName: featureCacheFileName,
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
          fileName: savedGroupsCacheFileName,
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
          fileName: featureCacheFileName,
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
          fileName: savedGroupsCacheFileName,
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
      fileName: featureCacheFileName,
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
