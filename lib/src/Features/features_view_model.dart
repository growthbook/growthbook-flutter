import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/Utils/crypto.dart';
import 'package:growthbook_sdk_flutter/src/Utils/feature_url_builder.dart';

class FeatureViewModel {
  FeatureViewModel({
    required this.delegate,
    required this.source,
    required this.encryptionKey,
    this.backgroundSync,
  });
  final FeaturesFlowDelegate delegate;
  final FeatureDataSource source;
  final String encryptionKey;
  final bool? backgroundSync;

  final CachingManager manager = CachingManager();
  final utf8Encoder = const Utf8Encoder();
  final utf8Decoder = const Utf8Decoder();

  Future<void> connectBackgroundSync() async {
    await source.fetchFeatures(
      featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS,
      (data) {
        delegate.featuresFetchedSuccessfully(gbFeatures: data.features!, isRemote: false);
        prepareFeaturesData(data);
      },
      (e, s) => delegate.featuresFetchFailed(
        error: GBError(
          error: e,
          stackTrace: s.toString(),
        ),
        isRemote: false,
      ),
    );
  }

  Future<void> fetchFeatures(String? apiUrl, {bool remoteEval = false, RemoteEvalModel? payload}) async {
    final receivedData = await manager.getContent(fileName: Constant.featureCache);

    if (receivedData == null) {
      await source.fetchFeatures(
        (data) {
          delegate.featuresFetchedSuccessfully(
            gbFeatures: data.features!,
            isRemote: false,
          );
          cacheFeatures(data);
        },
        (e, s) => delegate.featuresFetchFailed(
          error: GBError(
            error: e,
            stackTrace: s.toString(),
          ),
          isRemote: true,
        ),
      );
    } else {
      String receivedDataJson = utf8Decoder.convert(receivedData);
      final receiveFeatureJsonMap = json.decode(receivedDataJson);

      GBFeatures featureMap = {};
      if (encryptionKey.isNotEmpty) {
        receiveFeatureJsonMap.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            featureMap[key] = GBFeature.fromJson(value);
          }
        });
      } else {
        featureMap = FeaturedDataModel.fromJson(receiveFeatureJsonMap).features ?? {};
      }

      delegate.featuresFetchedSuccessfully(gbFeatures: featureMap, isRemote: false);
    }

    if (apiUrl != null) {
      if (remoteEval) {
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
            });
      } else {
        await source.fetchFeatures(
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
    }
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
      delegate.featuresFetchedSuccessfully(gbFeatures: data.features!, isRemote: true);
      final featureData = utf8Encoder.convert(jsonEncode(data.features));
      final featureDataOnUint8List = Uint8List.fromList(featureData);
      manager.putData(
        fileName: Constant.featureCache,
        content: featureDataOnUint8List,
      );

      if (data.savedGroups != null) {
        delegate.savedGroupsFetchedSuccessfully(savedGroups: data.savedGroups!, isRemote: true);
        final savedGroupsData = utf8Encoder.convert(jsonEncode(data.savedGroups));
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
        delegate.featuresFetchedSuccessfully(gbFeatures: extractedFeatures, isRemote: true);
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
        delegate.savedGroupsFetchedSuccessfully(savedGroups: extractedSavedGroups, isRemote: false);
        final savedGroupsData = utf8Encoder.convert(jsonEncode(extractedSavedGroups));
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
    final featureData = utf8Encoder.convert(jsonEncode(data.features));
    final featureDataOnUint8List = Uint8List.fromList(featureData);
    manager.putData(
      fileName: Constant.featureCache,
      content: featureDataOnUint8List,
    );
  }
}
