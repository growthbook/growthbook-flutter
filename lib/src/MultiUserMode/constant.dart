import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_variation_meta.dart';

typedef TrackingCallBackWithUser = void Function(GBTrackData)?;

typedef FeatureUsageCallbackWithUser = void Function(String, GBFeatureResult);

typedef FeatureRefreshCallback = void Function(bool);
