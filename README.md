# GrowthBook SDK for flutter.

![](GrowthBook-hero-flutter.png)



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
growthbook_sdk_flutter: ^1.1.0
```

## Integration

Integration is super easy:

1. Create a GrowthBook API key from the GrowthBook App.
2. Initialize the SDK at the start of your app using the API key, as below.

Now you can start/stop tests, adjust coverage and variation weights, and apply a winning variation to 100% of traffic, all within the Growth Book App without deploying code changes to your site.

```dart
final GrowthBookSDK sdkInstance = GBSDKBuilderApp(
  apiKey: "<API_KEY>",
  attributes: {
    /// Specify attributes.
  },
  growthBookTrackingCallBack: (gbExperiment, gbExperimentResult) {},
  hostURL: '<GrowthBook_URL>',
).initialize();

```

There are additional properties which can be setup at the time of initialization

```dart
    final GrowthBookSDK newSdkInstance = GBSDKBuilderApp(
    apiKey: "<API_KEY>",
    attributes: {
     /// Specify user attributes.
    },
    growthBookTrackingCallBack: (gbExperiment, gbExperimentResult) {},
    hostURL: '<GrowthBook_URL>',
).setNetworkDispatcher(
  // set network dispatcher.
)
   .setForcedVariations({})
   . // Set forced variations
   setQAMode(true)// Set qamode
   .initialize();

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
}

/// The result of running an Experiment given a specific Context
class GBExperimentResult {
  GBExperimentResult({
    this.inExperiment,
    this.variationID,
    this.value,
    this.hasAttributes,
    this.hashValue,
  });

  /// Whether or not the user is part of the experiment
  bool? inExperiment;

  /// The array index of the assigned variation
  int? variationID;

  /// The array value of the assigned variation
  dynamic value;

  /// The user attribute used to assign a variation
  String? hasAttributes;

  /// The value of that attribute
  String? hashValue;
}

```

## License

This project uses the MIT license. The core GrowthBook app will always remain open and free, although we may add some commercial enterprise add-ons in the future.