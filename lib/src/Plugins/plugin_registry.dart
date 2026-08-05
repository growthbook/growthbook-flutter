import 'dart:developer';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Holds all registered plugins and dispatches lifecycle and evaluation events
/// to each one.
///
/// Every dispatch method iterates the full plugin list so that a failure in one
/// plugin does not skip subsequent plugins.
class PluginRegistry {
  PluginRegistry(this._plugins);

  static final empty = PluginRegistry([]);

  final List<GrowthBookPlugin> _plugins;

  void initialize(String clientKey) {
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
    for (final plugin in _plugins) {
      try {
        plugin.onFeatureEvaluated(featureKey, result, attributes);
      } catch (e) {
        log('GrowthBookPlugin.onFeatureEvaluated error: $e');
      }
    }
  }

  Future<void> close() async {
    for (final plugin in _plugins) {
      try {
        await plugin.close();
      } catch (e) {
        log('GrowthBookPlugin.close error: $e');
      }
    }
  }
}
