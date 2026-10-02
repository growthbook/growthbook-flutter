import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/options.dart';
import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';

/// Invokes the consumer-supplied evaluation callbacks without letting a
/// throwing callback escape into evaluation.
///
/// Both callbacks are analytics sinks owned by the host app: a third-party SDK
/// that is not initialised yet, a sink torn down while a widget was disposing,
/// a serializer that chokes on an unexpected value. `PluginRegistry` already
/// treats plugin dispatch that way; these two paths did not, so one bad sink
/// took the caller's `feature()` or `run()` down with it.
///
/// The callback is read per invocation rather than captured, so a sink
/// installed through `GrowthBookSDK.setTrackingCallback` mid-evaluation is
/// never called on a stale reference.
extension CallbackInvoker on Options {
  /// Reports an experiment exposure to the tracking callback, if one is set.
  void notifyExperimentViewed(GBTrackData trackData) {
    final callback = trackingCallBackWithUser;
    if (callback == null) return;
    try {
      callback(trackData);
    } catch (e) {
      logger.e('trackingCallBack threw for experiment '
          '"${trackData.experiment.key}": $e');
    }
  }

  /// Reports a feature evaluation to the feature usage callback, if one is set.
  void notifyFeatureUsage(String featureKey, GBFeatureResult result) {
    final callback = featureUsageCallbackWithUser;
    if (callback == null) return;
    try {
      callback(featureKey, result);
    } catch (e) {
      logger.e('featureUsageCallback threw for feature "$featureKey": $e');
    }
  }
}
