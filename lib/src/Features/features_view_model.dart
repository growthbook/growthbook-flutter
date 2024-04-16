import 'dart:convert';
import 'dart:developer';

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

  // Caching Manager
  final CachingManager manager = CachingManager();

  Future<void> fetchFeature() async {
    GBFeatures? receivedData = manager.getData(Constant.featureCache);

    if (receivedData == null) {
      if (backgroundSync ?? false) {
        await source.fetchFeatures(
          featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS,
          (data) => delegate.featuresFetchedSuccessfully(data.features),
          (e, s) => delegate.featuresFetchFailed(
            GBError(
              error: e,
              stackTrace: s.toString(),
            ),
          ),
          encryptionKey,
        );
      } else {
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
          encryptionKey,
        );
      }
    } else {
      final data = FeaturedDataModel.fromJson(receivedData);
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
        delegate.featuresFetchedSuccessfully(features);

        final featureData = utf8.encode(jsonEncode(features));
        manager.putData(Constant.featureCache, featureData);
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
        manager.putData(Constant.featureCache, featureData);
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
    final GBFeatures features = data.features;
    manager.putData(Constant.featureCache, features);
  }
}
