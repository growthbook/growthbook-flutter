import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

typedef TrackingCallBackWithUser = void Function(GBTrackData)?;

typedef FeatureUsageCallbackWithUser = void Function(String, GBFeatureResult);

typedef FeatureRefreshCallback = void Function(bool);

/// Reports an experiment the evaluators resolved, including one reached through
/// a feature rule rather than a direct `run(...)` call.
typedef ExperimentEvalCallback = void Function(GBExperiment, GBExperimentResult);
