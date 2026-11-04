// ignore_for_file: constant_identifier_names

/// Builds every endpoint the SDK talks to, so the host rules live in one place.
///
/// Streaming may be served from a different host than the API — a GrowthBook
/// Proxy in front of a CDN, for example — so [streamingHost] is applied to the
/// server-sent events endpoint and falls back to [apiHost] when it is not set,
/// mirroring the reference JS SDK's `getApiHosts()`.
class FeatureURLBuilder {
  static const String featurePath = "api/features";
  static const String eventsPath = "sub";
  static const String remoteEvalPath = "api/eval";

  const FeatureURLBuilder({
    required this.apiHost,
    this.streamingHost,
  });

  /// Host serving the features and remote-evaluation endpoints.
  final String? apiHost;

  /// Host serving the streaming endpoint. Falls back to [apiHost] when null.
  final String? streamingHost;

  /// Returns the endpoint for [featureRefreshStrategy], or null when the host
  /// or [clientKey] is missing.
  ///
  /// A path on the host is preserved, so an SDK deployed under
  /// `https://proxy.example.com/growthbook` keeps that prefix; trailing slashes
  /// on the host are dropped rather than doubled.
  String? buildUrl(
    String? clientKey, {
    FeatureRefreshStrategy featureRefreshStrategy =
        FeatureRefreshStrategy.STALE_WHILE_REVALIDATE,
  }) {
    final host =
        featureRefreshStrategy == FeatureRefreshStrategy.SERVER_SENT_EVENTS
            ? (streamingHost ?? apiHost)
            : apiHost;

    if (host == null || host.isEmpty || clientKey == null) return null;

    final uri = Uri.tryParse(host);
    if (uri == null) return null;

    var basePath = uri.path;
    while (basePath.endsWith('/')) {
      basePath = basePath.substring(0, basePath.length - 1);
    }

    return uri
        .replace(
            path: '$basePath/${_endpoint(featureRefreshStrategy)}/$clientKey')
        .toString();
  }

  static String _endpoint(FeatureRefreshStrategy featureRefreshStrategy) {
    switch (featureRefreshStrategy) {
      case FeatureRefreshStrategy.STALE_WHILE_REVALIDATE:
        return featurePath;
      case FeatureRefreshStrategy.SERVER_SENT_EVENTS:
        return eventsPath;
      case FeatureRefreshStrategy.SERVER_SENT_REMOTE_FEATURE_EVAL:
        return remoteEvalPath;
    }
  }
}

enum FeatureRefreshStrategy {
  STALE_WHILE_REVALIDATE,
  SERVER_SENT_EVENTS,
  SERVER_SENT_REMOTE_FEATURE_EVAL
}
