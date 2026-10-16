import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Holds all registered plugins and dispatches lifecycle and evaluation events
/// to each one.
///
/// Every dispatch method iterates the full plugin list so that a failure in one
/// plugin does not skip subsequent plugins.
class PluginRegistry {
  PluginRegistry(this._plugins);

  /// A registry with no plugins. A fresh instance each time, because [close]
  /// latches — a shared one would carry another SDK's shutdown with it.
  static PluginRegistry get empty => PluginRegistry(const []);

  final List<GrowthBookPlugin> _plugins;

  /// Set by [close]. Dispatching stops here rather than in each plugin:
  /// stopping the tracking plugin's timer still let evaluations refill its
  /// buffer, and a full batch would then send another request long after the
  /// app asked the SDK to shut down.
  bool _isClosed = false;

  void initialize(String clientKey) {
    if (_isClosed) return;
    for (final plugin in _plugins) {
      try {
        plugin.initialize(clientKey);
      } catch (e) {
        log('GrowthBookPlugin.initialize error: $e');
      }
    }
  }

  void onExperimentViewed(
    GBExperiment experiment,
    GBExperimentResult result,
    Map<String, dynamic>? attributes,
  ) {
    if (_isClosed) return;
    for (final plugin in _plugins) {
      try {
        plugin.onExperimentViewed(experiment, result, attributes);
      } catch (e) {
        log('GrowthBookPlugin.onExperimentViewed error: $e');
      }
    }
  }

  void onFeatureEvaluated(
    String featureKey,
    GBFeatureResult result,
    Map<String, dynamic>? attributes,
  ) {
    if (_isClosed) return;
    for (final plugin in _plugins) {
      try {
        plugin.onFeatureEvaluated(featureKey, result, attributes);
      } catch (e) {
        log('GrowthBookPlugin.onFeatureEvaluated error: $e');
      }
    }
  }

  /// Sends what every plugin holds without shutting any of them down.
  Future<void> flush() async {
    if (_isClosed) return;
    for (final plugin in _plugins) {
      try {
        await plugin.flush();
      } catch (e) {
        log('GrowthBookPlugin.flush error: $e');
      }
    }
  }

  /// Ends the registry. Idempotent, so an app that closes explicitly and then
  /// drops the SDK does not shut its plugins down twice.
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    for (final plugin in _plugins) {
      try {
        await plugin.close();
      } catch (e) {
        log('GrowthBookPlugin.close error: $e');
      }
    }
  }
}
