import 'package:growthbook_sdk_flutter/src/Model/gb_option.dart';

class FeatureURLBuilder {
  static const String featurePath = "api/features";
  static const String eventsPath = "sub";
  static const String remoteEvalPath = "api/eval";
  static const String defaultStreamingHost = "https://cdn.growthbook.io";

  GBOptions gbOptions;

  FeatureURLBuilder({required this.gbOptions});

  String buildUrl(
    String? apiKey, {
    FeatureRefreshStrategy featureRefreshStrategy =
        FeatureRefreshStrategy.STALE_WHILE_REVALIDATE,
  }) {
    String endpoint = '';
    switch (featureRefreshStrategy) {
      case FeatureRefreshStrategy.STALE_WHILE_REVALIDATE:
        endpoint = featurePath;
        break;
      case FeatureRefreshStrategy.SERVER_SENT_EVENTS:
        endpoint = eventsPath;
        break;
      case FeatureRefreshStrategy.SERVER_SENT_REMOTE_FEATURE_EVAL:
        endpoint = remoteEvalPath;
        break;
    }
    String baseUrl;
    if (featureRefreshStrategy == FeatureRefreshStrategy.SERVER_SENT_EVENTS) {
      baseUrl = gbOptions.streamingHost ?? defaultStreamingHost;
    } else {
      baseUrl = gbOptions.apiHost;
    }
    String baseUrlWithFeaturePath =
        baseUrl.endsWith('/') ? '$baseUrl$endpoint' : '$baseUrl/$endpoint';

    return '$baseUrlWithFeaturePath/$apiKey';
  }
}

enum FeatureRefreshStrategy {
  // ignore: constant_identifier_names
  STALE_WHILE_REVALIDATE,
  SERVER_SENT_EVENTS,
  SERVER_SENT_REMOTE_FEATURE_EVAL
}
