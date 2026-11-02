import 'dart:async';

import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/options.dart';
import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';

/// Dispatches an evaluation to everything listening for it, without letting a
/// listener escape into evaluation.
///
/// The tracking and feature usage callbacks are analytics sinks owned by the
/// host app: a third-party SDK that is not initialised yet, a sink torn down
/// while a widget was disposing, a serializer that chokes on an unexpected
/// value. `PluginRegistry` already treats plugin dispatch that way; these two
/// paths did not, so one bad sink took the caller's `feature()` or `run()`
/// down with it. A callback declared `void` but written `async` is guarded
/// too: its failure arrives in the returned future, long after the try block
/// has been left.
///
/// The callbacks are read per invocation rather than captured, so a sink
/// replaced between two exposures is not called again.
extension CallbackInvoker on Options {
  /// Reports an experiment exposure to the tracking callback, if one is set.
  void notifyExperimentViewed(GBTrackData trackData) {
    final callback = trackingCallBackWithUser;
    if (callback == null) return;
    _guard(
      () => callback(trackData) as Object?,
      'trackingCallBack threw for experiment '
      '"${trackData.experiment.key}"',
    );
  }

  /// Reports a feature evaluation to the feature usage callback, if one is set.
  void notifyFeatureUsage(String featureKey, GBFeatureResult result) {
    final callback = featureUsageCallbackWithUser;
    if (callback == null) return;
    _guard(
      () => callback(featureKey, result) as Object?,
      'featureUsageCallback threw for feature "$featureKey"',
    );
  }
}

/// Runs [body] and reports anything it throws, synchronously or later.
///
/// Both callback types are declared to return void, which does not stop a
/// caller from passing an `async` closure — analytics SDKs are commonly
/// asynchronous. The error of such a closure never reaches the enclosing
/// catch: it completes the future the closure returned, which nobody awaits,
/// and surfaces as an unhandled zone error. Inspecting the return value is the
/// only way to reach it.
void _guard(Object? Function() body, String message) {
  try {
    final result = body();
    if (result is Future) {
      result.catchError((Object e, StackTrace st) {
        logger.e(message, error: e, stackTrace: st);
      });
    }
  } catch (e, st) {
    logger.e(message, error: e, stackTrace: st);
  }
}
