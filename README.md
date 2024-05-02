# GrowthBook SDK for flutter.

![](https://docs.growthbook.io/images/hero-flutter-sdk.png)



## Overview

GrowthBook is an open source feature flagging and experimentation platform that makes it easy to adjust what features are shown users, and run A/B tests, without deploying new code. There are two parts to GrowthBook, the GrowthBook Application, and the SDKs which implement this functionality to your code base. This Flutter SDK allows you to use GrowthBook with your Flutter based mobile application.

![](https://camo.githubusercontent.com/b1d9ad56ab51c4ad1417e9a5ad2a8fe63bcc4755e584ec7defef83755c23f923/687474703a2f2f696d672e736869656c64732e696f2f62616467652f706c6174666f726d2d616e64726f69642d3645444238442e7376673f7374796c653d666c6174) ![](https://camo.githubusercontent.com/1fec6f0d044c5e1d73656bfceed9a78fd4121b17e82a2705d2a47f6fd1f0e3e5/687474703a2f2f696d672e736869656c64732e696f2f62616467652f706c6174666f726d2d696f732d4344434443442e7376673f7374796c653d666c6174)




- **Lightweight and fast**
- **Supports**
  - **Android**
  - **iOS**
  - **Mac**
  - **Windows**
- **Use your existing event tracking (GA, Segment, Mixpanel, custom)**
- **Adjust variation weights and targeting without deploying new code**



## Installation

1. Add GrowthBook SDK as dependency in your pubspec.yaml file.
```yaml
growthbook_sdk_flutter: ^latest-version
```

## Integration

Integration is super easy:

1. Create a GrowthBook API key from the GrowthBook App.
2. Initialize the SDK at the start of your app using the API key, as below.

Now you can start/stop tests, adjust coverage and variation weights, and apply a winning variation to 100% of traffic, all within the Growth Book App without deploying code changes to your site.

```dart
final GrowthBookSDK sdkInstance = await GBSDKBuilderApp(
  apiKey: "<API_KEY>",
  attributes: {
    /// Specify attributes.
  },
  growthBookTrackingCallBack: (gbExperiment, gbExperimentResult) {},
  hostURL: '<GrowthBook_URL>',
  backroundSync: Bool?
).initialize();

```

There are additional properties which can be setup at the time of initialization

```dart
    final GrowthBookSDK newSdkInstance = GBSDKBuilderApp(
    apiKey: "<API_KEY>",
    attributes: {
     /// Specify user attributes.
    },
    client: NetworkClient(), // Provide network dispatcher.
    growthBookTrackingCallBack: (gbExperiment, gbExperimentResult) {},
    hostURL: '<GrowthBook_URL>',
    forcedVariations: {} // Optional provide force variation.
    qaMode: true, // Set qamode
);
newSdkInstance.setStickyBucketService(stickyBucketService: GBStickyBucketingService());

await newSdkInstance.initialize();

```



## Usage

- Initialization returns SDK instance - GrowthBookSDK
  ###### Use sdkInstance to consume below features -

- The feature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.

  ```dart
    GBFeatureResult feature(String id) 
  ```

- The run method takes an Experiment object and returns an ExperimentResult

```dart
    GBExperimentResult run(GBExperiment experiment)   
```

- Get Context

```dart
    GBContext getGBContext()
```

- Get Features

```dart
    GBFeatures getFeatures()  
```



## Models

```dart
/// Defines the GrowthBook context.
class GBContext {
  GBContext({
    this.apiKey,
    this.hostURL,
    this.enabled,
    this.attributes,
    this.forcedVariation,
    this.qaMode,
    this.trackingCallBack,
    this.backgroundSync,
  });

  /// Registered API key for GrowthBook SDK.
  String? apiKey;

  /// Host URL for GrowthBook
  String? hostURL;

  /// Switch to globally disable all experiments. Default true.
  bool? enabled;

  /// Map of user attributes that are used to assign variations
  Map<String, dynamic>? attributes;

  /// Force specific experiments to always assign a specific variation (used for QA).
  Map<String, dynamic>? forcedVariation;

  /// If true, random assignment is disabled and only explicitly forced variations are used.
  bool? qaMode;

  /// A function that takes experiment and result as arguments.
  TrackingCallBack? trackingCallBack;

  /// Keys are unique identifiers for the features and the values are Feature objects.
  /// Feature definitions - To be pulled from API / Cache
  GBFeatures features = <String, GBFeature>{};

  ///Disable background streaming connection
  bool? backgroundSync;
}
```



```dart
/// A Feature object consists of possible values plus rules for how to assign values to users.
class GBFeature {
  GBFeature({
    this.rules,
    this.defaultValue,
  });

  /// The default value (should use null if not specified)
  ///2 Array of Rule objects that determine when and how the defaultValue gets overridden
  List<GBFeatureRule>? rules;

  ///  The default value (should use null if not specified)
  dynamic defaultValue;
}


/// Rule object consists of various definitions to apply to calculate feature value

class GBFeatureRule {
  GBFeatureRule({
    this.condition,
    this.coverage,
    this.force,
    this.variations,
    this.key,
    this.weights,
    this.nameSpace,
    this.hashAttribute,
    this.hashVersion,
    this.range,
    this.ranges,
    this.meta,
    this.filters,
    this.seed,
    this.name,
    this.phase,
  });

  /// Optional targeting condition
  GBCondition? condition;

  /// What percent of users should be included in the experiment (between 0 and 1, inclusive)
  double? coverage;

  /// Immediately force a specific value (ignore every other option besides condition and coverage)
  dynamic force;

  /// Run an experiment (A/B test) and randomly choose between these variations
  List<dynamic>? variations;

  /// The globally unique tracking key for the experiment (default to the feature key)
  String? key;

  /// How to weight traffic between variations. Must add to 1.
  List<double>? weights;

  /// A tuple that contains the namespace identifier, plus a range of coverage for the experiment.
  List? nameSpace;

  /// What user attribute should be used to assign variations (defaults to id)
  String? hashAttribute;
  
  /// The hash version to use (default to 1)
  int? hashVersion;

  /// A more precise version of coverage
  GBBucketRange? range;

  /// Ranges for experiment variations
  @Tuple2Converter()
  List<GBBucketRange>? ranges;

  /// Meta info about the experiment variations
  List<GBVariationMeta>? meta;

  /// Array of filters to apply to the rule
  List<GBFilter>? filters;

  /// Seed to use for hashing
  String? seed;

  /// Human-readable name for the experiment
  String? name;

  /// The phase id of the experiment
  String? phase;
}


/// Enum For defining feature value source.
enum GBFeatureSource {
  /// Queried Feature doesn't exist in GrowthBook.
  unknownFeature,

  /// Default Value for the Feature is being processed.
  defaultValue,

  /// Forced Value for the Feature is being processed.
  force,

  /// Experiment Value for the Feature is being processed.
  experiment
}

/// Result for Feature
class GBFeatureResult {
  GBFeatureResult({
    this.value,
    this.on,
    this.off,
    this.source,
    this.experiment,
    this.experimentResult,
  });

  /// The assigned value of the feature
  dynamic value;

  /// The assigned value cast to a boolean
  bool? on = false;

  /// The assigned value cast to a boolean and then negated
  bool? off = true;

  /// One of "unknownFeature", "defaultValue", "force", or "experiment"

  GBFeatureSource? source;

  /// When source is "experiment", this will be the Experiment object used
  GBExperiment? experiment;

  ///When source is "experiment", this will be an ExperimentResult object
  GBExperimentResult? experimentResult;
}
```



```dart
/// Defines a single experiment

class GBExperiment {
  GBExperiment({
    this.key,
    this.variations,
    this.namespace,
    this.condition,
    this.hashAttribute,
    this.weights,
    this.active = true,
    this.coverage,
    this.force,
    this.hashVersion,
    this.ranges,
    this.meta,
    this.filters,
    this.seed,
    this.name,
    this.phase,
  });

  /// The globally unique tracking key for the experiment
  String? key;

  /// The different variations to choose between
  List? variations = [];

  /// A tuple that contains the namespace identifier, plus a range of coverage for the experiment
  List? namespace;

  /// All users included in the experiment will be forced into the specific variation index
  String? hashAttribute;

  /// How to weight traffic between variations. Must add to 1.
  List? weights;

  /// If set to false, always return the control (first variation)
  bool active;

  /// What percent of users should be included in the experiment (between 0 and 1, inclusive)
  double? coverage;

  /// Optional targeting condition
  GBCondition? condition;

  /// All users included in the experiment will be forced into the specific variation index
  int? force;

  ///Check if experiment is not active.
  bool get deactivated => !active;

  /// The hash version to use (default to 1)
  int? hashVersion;

  /// Array of ranges, one per variation
  List<GBBucketRange>? ranges;

  /// Meta info about the variations
  List<GBVariationMeta>? meta;

  /// Array of filters to apply
  List<GBFilter>? filters;

  /// The hash seed to use
  String? seed;

  /// Human-readable name for the experiment
  String? name;

  /// Id of the current experiment phase
  String? phase;
}

/// The result of running an Experiment given a specific Context
class GBExperimentResult {
  GBExperimentResult({
    this.inExperiment,
    this.variationID,
    this.value,
    this.hashUsed,
    this.hasAttributes,
    this.hashValue,
    this.featureId,
    this.key,
    this.name,
    this.bucket,
    this.passthrough,
  });

  /// Whether or not the user is part of the experiment
  bool? inExperiment;

  /// The array index of the assigned variation
  int? variationID;

  /// The array value of the assigned variation
  dynamic value;

  bool? hashUsed;

  /// The user attribute used to assign a variation
  String? hasAttributes;

  String? featureId;

  /// The value of that attribute
  String? hashValue;

  /// The unique key for the assigned variation
  String? key;

  /// The human-readable name of the assigned variation
  String? name;

  /// The hash value used to assign a variation (double from 0 to 1)
  double? bucket;

  /// Used for holdout groups
  bool? passthrough;
}

The `inExperiment` flag will be false if the user was excluded from being part of the experiment for any reason (e.g. failed targeting conditions).

The `hashUsed` flag will only be true if the user was randomly assigned a variation. If the user was forced into a specific variation instead, this flag will be false.

/// Meta info about the variations
class GBVariationMeta {
  /// Used to implement holdout groups
  final bool? passthrough;

  /// A unique key for this variation
  final String? key;

  /// A human-readable name for this variation
  final String? name;

  GBVariationMeta({
    this.passthrough,
    this.key,
    this.name,
  });
}


///Used for remote feature evaluation to trigger the `TrackingCallback`
class GBTrackData {
  final Experiment experiment;
  final ExperimentResult result;

  GBTrackData({
    required this.experiment,
    required this.result,
  });
}

```
## Streaming updates

To enable streaming updates set backgroundSync variable to "true" and add streaming updates URL
```dart

final GrowthBookSDK sdkInstance = GBSDKBuilderApp(
  backgroundSync: true,
  apiKey: "<API_KEY>",
  attributes: {
    /// Specify attributes.
  },
  growthBookTrackingCallBack: (gbExperiment, gbExperimentResult) {},
  ).initializer();

```
## ParentCondition

A ParentCondition defines a prerequisite. It consists of a parent feature's id (`String`), a condition (`GBCondition`),  and an optional gate (`bool`) flag.

Instead of evaluating against attributes, the condition evaluates against the returned value of the parent feature. The condition will always reference a "value" property. Here is an example of a gating prerequisite where the parent feature must be toggled on:
```dart

{
  "id": "parent-feature",
  "condition": {
    "value": {
      "$exists": true
    }
  },
  "gate": true
}

```


## Remote Evaluation

This mode brings the security benefits of a backend SDK to the front end by evaluating feature flags exclusively on a private server. Using Remote Evaluation ensures that any sensitive information within targeting rules or unused feature variations are never seen by the client. Note that Remote Evaluation should not be used in a backend context.

You must enable Remote Evaluation in your SDK Connection settings. Cloud customers are also required to self-host a GrowthBook Proxy Server or custom remote evaluation backend.

To use Remote Evaluation, add the `remoteEval: true` property to your SDK instance. A new evaluation API call will be made any time a user attribute or other dependency changes. You may optionally limit these API calls to specific attribute changes by setting the `cacheKeyAttributes` property (an array of attribute names that, when changed, trigger a new evaluation call).

```dart

var sdkInstance: GrowthBookSDK = GrowthBookBuilder(apiHost: <GrowthBook/API_KEY>, clientKey: <GrowthBook/ClientKey>, attributes: <[String: Any]>, trackingCallback: { experiment, experimentResult in 
    }, refreshHandler: { isRefreshed in
    }, remoteEval: true)
    .initializer()
    
```


If you would like to implement Sticky Bucketing while using Remote Evaluation, you must configure your remote evaluation backend to support Sticky Bucketing. You will not need to provide a StickyBucketService instance to the client side SDK.


## Sticky Bucketing

Sticky bucketing ensures that users see the same experiment variant, even when user session, user login status, or experiment parameters change. See the [Sticky Bucketing docs](https://docs.growthbook.io/app/sticky-bucketing) for more information. If your organization and experiment supports sticky bucketing, you must implement an instance of the `GBStickyBucketingService` to use Sticky Bucketing.

## License

This project uses the MIT license. The core GrowthBook app will always remain open and free, although we may add some commercial enterprise add-ons in the future.