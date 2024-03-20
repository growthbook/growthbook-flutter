class FeatureURLBuilder {
  static const String featurePath = "api/features";
  static const String eventsPath = "sub";

  static String buildUrl(
    String apiKey,
    String path, {
    FeatureRefreshStrategy featureRefreshStrategy =
        FeatureRefreshStrategy.STALE_WHILE_REVALIDATE,
  }) {
    String endpointPath =
        featureRefreshStrategy == FeatureRefreshStrategy.SERVER_SENT_EVENTS
            ? eventsPath
            : featurePath;

    return '$endpointPath/$apiKey';
  }
}

enum FeatureRefreshStrategy {
  STALE_WHILE_REVALIDATE,
  SERVER_SENT_EVENTS,
}
