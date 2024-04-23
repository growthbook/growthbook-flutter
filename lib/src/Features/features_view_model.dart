import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
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
      (data) => delegate.featuresFetchedSuccessfully(data.features),
      (e, s) => delegate.featuresFetchFailed(
        GBError(
          error: e,
          stackTrace: s.toString(),
        ),
      ),
    );
  }

  Future<void> fetchFeature() async {
    final receivedData =
        await manager.getContent(fileName: Constant.featureCache);

    if (receivedData == null) {
      await source.fetchFeatures(
        (data) {
          delegate.featuresFetchedSuccessfully(
            data.features,
          );
          cacheFeatures(data);
        },
        (e, s) => delegate.featuresFetchFailed(
          GBError(
            error: e,
            stackTrace: s.toString(),
          ),
        ),
      );
    } else {
      String receivedDataJson = utf8.decode(receivedData);
      final receivedDataJsonMap = json.decode(receivedDataJson);
      final data = FeaturedDataModel.fromJson(receivedDataJsonMap);
      delegate.featuresFetchedSuccessfully(data.features);
    }
  }

  void prepareFeaturesData(dynamic data) {
    try {
      final Map<String, dynamic>? jsonPetitions = jsonDecode(data);
      switch (jsonPetitions) {
        case null:
          log("JSON is null.");
          break;

        default:
          final features = jsonPetitions!["features"];
          final hasFeaturesKey = jsonPetitions.containsKey("features");

          hasFeaturesKey
              ? handleValidFeatures(features)
              : log("Missing 'features' key.");

          break;
      }
    } catch (e, s) {
      handleException(e, s);
    }
  }

  void handleValidFeatures(dynamic features) {
    switch (features) {
      case Map<String, GBFeature>:
        delegate.featuresAPIModelSuccessfully(features);
        delegate.featuresFetchedSuccessfully(features);

        final featureData = utf8.encode(jsonEncode(features));
        manager.putData(fileName: Constant.featureCache, content: featureData);
        break;

      default:
        handleInvalidFeatures(features);
    }
  }

  void handleInvalidFeatures(Map<String, dynamic>? jsonPetitions) {
    final encryptedString = jsonPetitions?["encryptedFeatures"];

    if (encryptedString == null ||
        encryptedString is! String ||
        encryptedString.isEmpty) {
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
        delegate.featuresFetchedSuccessfully(extractedFeatures);
        final featureData = utf8.encode(jsonEncode(extractedFeatures));
        manager.putData(fileName: Constant.featureCache, content: featureData);
      } else {
        logError("Failed to extract features from encrypted string.");
      }
    } catch (e, s) {
      delegate.featuresFetchFailed(GBError(
        error: e,
        stackTrace: s.toString(),
      ));
    }
  }

  void handleException(dynamic e, dynamic s) {
    delegate.featuresFetchFailed(GBError(
      error: e,
      stackTrace: s.toString(),
    ));
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
