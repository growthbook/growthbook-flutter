import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

typedef TrackingCallBackWithUser = void Function(GBTrackData)?;

typedef FeatureUsageCallbackWithUser = void Function(String, GBFeatureResult);

typedef FeatureRefreshCallback = void Function(bool);
