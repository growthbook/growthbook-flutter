class FeatureURLBuilder {
  static const String featurePath = "api/features";
  static const String eventsPath = "sub";
  static const String remoteEvalPath = "api/eval";

  static String buildUrl(
      String? hostUrl,
      String? apiKey, {
        FeatureRefreshStrategy featureRefreshStrategy =
            FeatureRefreshStrategy.STALE_WHILE_REVALIDATE,
      }) {
    String endpoint = '';
    switch(featureRefreshStrategy) {
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
    String baseUrlWithFeaturePath = hostUrl!.endsWith('/')
        ? '$hostUrl$endpoint' : '$hostUrl/$endpoint';

    return '$baseUrlWithFeaturePath/$apiKey';
  }
}

enum FeatureRefreshStrategy {
  // ignore: constant_identifier_names
  STALE_WHILE_REVALIDATE, SERVER_SENT_EVENTS, SERVER_SENT_REMOTE_FEATURE_EVAL
}
