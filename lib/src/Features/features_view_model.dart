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

  Future<void> connectBackgroundSync() async {
    await source.fetchFeatures(
      featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS,
      (data) => delegate.featuresFetchedSuccessfully(gbFeatures: data.features, isRemote: false),
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
            gbFeatures: data.features,
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
      String receivedDataJson = utf8.decode(receivedData);
      final receivedDataJsonMap = json.decode(receivedDataJson);
      final data = FeaturedDataModel.fromJson(receivedDataJsonMap);
      delegate.featuresFetchedSuccessfully(gbFeatures: data.features, isRemote: false);
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
      if (data.features.isEmpty) {
        log("JSON is null.");
      } else {
        handleValidFeatures(data);
      }
    } catch (e, s) {
      handleException(e, s);
    }
  }

  void handleValidFeatures(FeaturedDataModel data) {
    if (data.features.isNotEmpty) {
      delegate.featuresAPIModelSuccessfully(data);
      // todo manager content save
      //    manager.putData(fileName: Constant.featureCache, content: utf8.encode(data.features.toString()));
      delegate.featuresFetchedSuccessfully(gbFeatures: data.features, isRemote: true);
    } else {
      handleInvalidFeatures(data.features);
    }
  }

  void handleInvalidFeatures(Map<String, dynamic>? jsonPetitions) {
    final encryptedString = jsonPetitions?["encryptedFeatures"];

    if (encryptedString == null || encryptedString is! String || encryptedString.isEmpty) {
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
        encryptedString,
        encryptionKey,
      );

      if (extractedFeatures != null) {
        delegate.featuresFetchedSuccessfully(gbFeatures: extractedFeatures, isRemote: false);
        final featureData = utf8.encode(jsonEncode(extractedFeatures));
        manager.putData(fileName: Constant.featureCache, content: featureData);
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
    // final GBFeatures features = data.toJson(); //.features;
    String jsonString = json.encode(data.toJson());
    Uint8List bytes = utf8.encode(jsonString);

    manager.putData(fileName: Constant.featureCache, content: bytes);
  }
}
