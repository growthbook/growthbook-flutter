# GrowthBook Flutter SDK

<!-- Trigger release for pub.dev publishing workflow test -->

<div align="center">

![GrowthBook Flutter SDK](https://docs.growthbook.io/images/hero-flutter-sdk.png)

[![pub package](https://img.shields.io/pub/v/growthbook_sdk_flutter.svg)](https://pub.dev/packages/growthbook_sdk_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Platform](https://img.shields.io/badge/platform-flutter-blue)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)

**🎯 Feature flags • 🧪 A/B testing • 📊 Analytics integration**

[Quick Start](#-quick-start) • [Features](#-features) • [Documentation](#-documentation) • [Examples](#-examples) • [Resources](#-resources)

</div>

## Overview

GrowthBook is an open source feature flagging and experimentation platform. This Flutter SDK allows you to use GrowthBook with your Flutter based mobile application.

**Platform Support:**

- 📱 **Android** 21+ • **iOS** 12+ 
- 📺 **tvOS** 13+ • ⌚ **watchOS** 7+
- 🖥️ **macOS** • **Windows** • **Linux**
- 🌐 **Web** (Flutter Web)

---

## ✨ Features

- **Lightweight** - Minimal performance impact
- **Type Safe** - Full Dart/Flutter type safety
- **Caching** - Smart caching with TTL and stale-while-revalidate
- **Cross-platform** - Works on Android, iOS, Web, Desktop

### 🏗️ **Core Capabilities**

- **Feature Flags** - Toggle features on/off without code deployments
- **A/B Testing** - Run experiments with statistical significance  
- **Targeting** - Advanced user segmentation, variation weights and targeting rules
- **Tracking** - Use your existing event tracking (GA, Segment, Mixpanel, custom)
- **Real-time Updates** - Features update instantly via streaming

### 🎯 **Advanced Features**

- **Sticky Bucketing** - Consistent user experiences across sessions
- **Remote Evaluation** - Server-side evaluation for enhanced security
- **Multi-variate Testing** - Test multiple variations simultaneously
- **Rollout Management** - Gradual feature rollouts with traffic control

## 📋 Supported Features

| Feature | Support | Since Version |
|---------|---------|---------------|
| ✅ **Feature Flags** | Full Support | All versions |
| ✅ **A/B Testing** | Full Support | All versions |
| ✅ **Sticky Bucketing** | Full Support | ≥ v3.8.0 |
| ✅ **Remote Evaluation** | Full Support | ≥ v3.7.0 |
| ✅ **Streaming Updates** | Full Support | ≥ v3.4.0 |
| ✅ **Prerequisites** | Full Support | ≥ v3.2.0 |
| ✅ **Encrypted Features** | Full Support | ≥ v3.1.0 |
| ✅ **v2 Hashing** | Full Support | ≥ v3.1.0 |
| ✅ **SemVer Targeting** | Full Support | ≥ v3.1.0 |
| ✅ **TTL Caching** | Full Support | ≥ v3.9.10 |

> 📖 **[View complete feature support matrix →](https://docs.growthbook.io/lib/flutter#supported-features)**

---

## 🚀 Quick Start

> 📖 **[View official installation guide →](https://docs.growthbook.io/lib/flutter#installation)**

### 1. Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  growthbook_sdk_flutter: ^3.9.10
```

### 2. Basic Setup

> 📖 **[View complete usage guide →](https://docs.growthbook.io/lib/flutter#quick-usage)**

```dart
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

// Initialize the SDK
final sdk = await GBSDKBuilderApp(
  apiKey: "sdk_your_api_key",
  hostURL: "https://growthbook.io",
  attributes: {
    'id': 'user_123',
    'email': 'user@example.com',
    'country': 'US',
  },
  growthBookTrackingCallBack: (experiment, result) {
    // Track experiment exposures
    print('Experiment: ${experiment.key}, Variation: ${result.variationID}');
  },
).initialize();

// Use feature flags
final welcomeMessage = sdk.feature('welcome_message');
if (welcomeMessage.on) {
  print('Feature is enabled: ${welcomeMessage.value}');
}

// Run A/B tests
final buttonExperiment = GBExperiment(key: 'button_color_test');
final result = sdk.run(buttonExperiment);
final buttonColor = result.value ?? 'blue'; // Default color
```

### 3. Widget Integration

```dart
class MyHomePage extends StatelessWidget {
  final GrowthBookSDK sdk;
  
  @override
  Widget build(BuildContext context) {
    final newDesign = sdk.feature('new_homepage_design');
    
    return Scaffold(
      body: newDesign.on 
        ? NewHomepageWidget() 
        : ClassicHomepageWidget(),
    );
  }
}
```

---

## Analytics

```dart
final sdk = await GBSDKBuilderApp(
  apiKey: "your_api_key",
  growthBookTrackingCallBack: (experiment, result) {
    // Google Analytics
    FirebaseAnalytics.instance.logEvent(
      name: 'experiment_viewed',
      parameters: {
        'experiment_id': experiment.key,
        'variation_id': result.variationID,
        'variation_name': result.key,
      },
    );
    
    // Mixpanel
    Mixpanel.track('Experiment Viewed', {
      'Experiment ID': experiment.key,
      'Variation ID': result.variationID,
    });
    
    // Custom analytics
    YourAnalytics.trackExperiment(experiment, result);
  },
).initialize();
```

---

## 📚 Documentation

### Configuration Options

```dart
final sdk = await GBSDKBuilderApp(
  // Required
  apiKey: "sdk_your_api_key",
  hostURL: "https://growthbook.io",
  
  // User Context
  attributes: {
    'id': 'user_123',
    'email': 'user@example.com',
    'plan': 'premium',
    'country': 'US',
  },
  
  // Performance & Caching
  ttlSeconds: 300,              // Cache TTL (default: 60s)
  backgroundSync: true,         // Real-time updates
  
  // Testing & QA
  qaMode: false,                // Disable randomization for QA
  forcedVariations: {           // Force specific variations
    'button_test': 1,
  },
  
  // Analytics Integration
  growthBookTrackingCallBack: (experiment, result) {
    // Send to your analytics platform
    analytics.track('Experiment Viewed', {
      'experiment_id': experiment.key,
      'variation_id': result.variationID,
      'variation_name': result.key,
    });
  },
  
  // Advanced Features
  remoteEval: false,            // Server-side evaluation
  encryptionKey: "...",         // For encrypted features
).initialize();
```

### Feature Flag Usage

> 📖 **[View detailed feature usage guide →](https://docs.growthbook.io/lib/flutter#using-features)**

```dart
// Boolean flags
final isEnabled = sdk.feature('new_feature').on;

// String values
final welcomeText = sdk.feature('welcome_message').value ?? 'Welcome!';

// Number values  
final maxItems = sdk.feature('max_items').value ?? 10;

// JSON objects
final config = sdk.feature('app_config').value ?? {
  'theme': 'light',
  'animations': true,
};

// Check feature source
final feature = sdk.feature('premium_feature');
switch (feature.source) {
  case GBFeatureSource.experiment:
    print('Value from A/B test');
    break;
  case GBFeatureSource.force:
    print('Forced value');
    break;
  case GBFeatureSource.defaultValue:
    print('Default value');
    break;
}
```

### Experiments - A/B Testing

> 📖 **[View inline experiments guide →](https://docs.growthbook.io/lib/flutter#running-inline-experiments)**

```dart
// Define experiment
final experiment = GBExperiment(
  key: 'checkout_button_test',
  variations: ['🛒 Buy Now', '💳 Purchase', '✨ Get It Now'],
  weights: [0.33, 0.33, 0.34], // Traffic distribution
);

// Run experiment
final result = sdk.run(experiment);

// Use result
Widget buildButton() {
  final buttonText = result.value ?? '🛒 Buy Now';
  return ElevatedButton(
    onPressed: () => handlePurchase(),
    child: Text(buttonText),
  );
}

// Track conversion
if (purchaseCompleted) {
  // Your analytics will receive this via trackingCallBack
}
```

### User Attributes & Targeting

```dart
// Update user attributes dynamically
sdk.setAttributes({
  'plan': 'enterprise',
  'feature_flags_enabled': true,
  'last_login': DateTime.now().toIso8601String(),
});

// Target users with conditions
// Example: Show feature only to premium users in US
// This is configured in GrowthBook dashboard, not in code
```

---

## 🔧 Advanced Features

### Smart Caching Strategy

The SDK implements an intelligent caching system for optimal performance:

```dart
final sdk = await GBSDKBuilderApp(
  apiKey: "your_api_key",
  ttlSeconds: 300, // Cache TTL: 5 minutes
  backgroundSync: true, // Enable background refresh
).initialize();
```

#### **How it works:**

1. **🚀 Instant Response** - Serve cached features immediately
2. **🔄 Background Refresh** - Fetch updates in the background  
3. **⚡ Stale-While-Revalidate** - Show cached data while updating
4. **📊 Smart Invalidation** - Refresh only when needed

#### **Benefits:**

- ✅ **Zero loading delays** for feature flags
- ✅ **Always up-to-date** with background sync
- ✅ **Reduced API calls** with intelligent caching
- ✅ **Offline resilience** with cached fallbacks

### Sticky Bucketing

> 📖 **[Learn about sticky bucketing →](https://docs.growthbook.io/app/sticky-bucketing)**

Ensure consistent user experiences across sessions:

```dart
class MyAppStickyBucketService extends GBStickyBucketService {
  @override
  Future<Map<String, String>?> getAllAssignments(
    Map<String, dynamic> attributes,
  ) async {
    // Retrieve from local storage
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('gb_sticky_assignments');
    return json != null ? jsonDecode(json) : null;
  }
  
  @override
  Future<void> saveAssignments(
    Map<String, dynamic> attributes,
    Map<String, String> assignments,
  ) async {
    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gb_sticky_assignments', jsonEncode(assignments));
  }
}

// Use with SDK
final sdk = await GBSDKBuilderApp(
  apiKey: "your_api_key",
  stickyBucketService: MyAppStickyBucketService(),
).initialize();
```

### Remote Evaluation

> 📖 **[Learn about remote evaluation →](https://docs.growthbook.io/lib/remote-evaluation)**

For enhanced security and server-side evaluation:

```dart
final sdk = await GBSDKBuilderApp(
  apiKey: "your_api_key",
  remoteEval: true, // Enable remote evaluation
  attributes: userAttributes,
).initialize();

// Features are evaluated server-side
// Sensitive targeting rules never reach the client
```

### Real-time Updates

> 📖 **[Learn about streaming updates →](https://docs.growthbook.io/lib/streaming)**

```dart
final sdk = await GBSDKBuilderApp(
  apiKey: "your_api_key",
  backgroundSync: true, // Enable streaming updates
).initialize();

// Features automatically update when changed in GrowthBook
// No need to restart the app or refresh manually
```

---

## 💡 Examples

### E-commerce App

```dart
class ProductPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sdk = context.read<GrowthBookSDK>();
    
    // Feature flags
    final showReviews = sdk.feature('show_product_reviews').on;
    final freeShipping = sdk.feature('free_shipping_threshold').value ?? 50.0;
    
    // A/B test for pricing display
    final pricingExperiment = GBExperiment(key: 'pricing_display_test');
    final pricingResult = sdk.run(pricingExperiment);
    
    return Scaffold(
      body: Column(
        children: [
          ProductImage(),
          ProductTitle(),
          
          // Dynamic pricing display based on A/B test
          if (pricingResult.value == 'with_discount')
            PricingWithDiscount()
          else
            StandardPricing(),
            
          // Conditional features
          if (showReviews) ProductReviews(),
          if (freeShipping > 0) FreeShippingBanner(threshold: freeShipping),
          
          AddToCartButton(),
        ],
      ),
    );
  }
}
```

### Gradual Feature Rollout

```dart
class NewFeatureService {
  final GrowthBookSDK sdk;
  
  NewFeatureService(this.sdk);
  
  bool get isNewDashboardEnabled {
    final feature = sdk.feature('new_dashboard_v2');
    
    // Feature is rolled out gradually:
    // 0% → 5% → 25% → 50% → 100%
    // Configured in GrowthBook dashboard
    return feature.on;
  }
  
  Widget buildDashboard() {
    return isNewDashboardEnabled 
      ? NewDashboardWidget()
      : LegacyDashboardWidget();
  }
}
```

---

## 🛠️ Development

### Local Development Setup

#### **1. Clone and Setup**

```bash
# Clone the repository
git clone https://github.com/growthbook/growthbook-flutter.git
cd growthbook-flutter

# Install dependencies
flutter pub get

# Generate code (for json_serializable)
dart run build_runner build --delete-conflicting-outputs
```

#### **2. Run Tests**

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/features/feature_test.dart
```

#### **3. Code Generation**

The SDK uses `json_serializable` for JSON parsing. When you modify model classes with `@JsonSerializable()`, run:

```bash
# Watch for changes and auto-generate
dart run build_runner watch

# One-time generation
dart run build_runner build --delete-conflicting-outputs
```

#### **4. Linting and Formatting**

```bash
# Check linting
dart analyze

# Format code
dart format .

# Fix auto-fixable issues
dart fix --apply
```

#### **5. Building Examples**

```bash
cd example
flutter pub get
flutter run
```

### Testing

```dart
// Mock SDK for testing
class MockGrowthBookSDK implements GrowthBookSDK {
  final Map<String, dynamic> mockFeatures;
  
  MockGrowthBookSDK({required this.mockFeatures});
  
  @override
  GBFeatureResult feature(String key) {
    final value = mockFeatures[key];
    return GBFeatureResult(
      value: value,
      on: value == true,
      source: GBFeatureSource.force,
    );
  }
}

// Use in tests
void main() {
  testWidgets('shows new feature when enabled', (tester) async {
    final mockSDK = MockGrowthBookSDK(
      mockFeatures: {'new_feature': true},
    );
    
    await tester.pumpWidget(MyApp(sdk: mockSDK));
    
    expect(find.text('New Feature'), findsOneWidget);
  });
}
```

### Build Integration

```dart
// Different configurations for different environments
final sdk = await GBSDKBuilderApp(
  apiKey: kDebugMode 
    ? "sdk_dev_your_dev_key"
    : "sdk_prod_your_prod_key",
  hostURL: kDebugMode 
    ? "https://growthbook-dev.yourcompany.com"
    : "https://growthbook.yourcompany.com",
  qaMode: kDebugMode, // Disable randomization in debug
).initialize();
```

### Contributing

We welcome contributions! Here's how to get started:

1. **Fork the repository** and create a feature branch
2. **Make your changes** following our coding conventions
3. **Add tests** for any new functionality
4. **Ensure all tests pass**: `flutter test`
5. **Format code**: `dart format .`
6. **Submit a pull request** with a clear description

#### **Pull Request Guidelines:**

- ✅ Include tests for new features
- ✅ Update documentation if needed
- ✅ Follow existing code style
- ✅ Keep commits atomic and well-described
- ✅ Reference any related issues

#### **Release Process:**

- Uses automated releases via **release-please**
- Follow conventional commits: `feat:`, `fix:`, `docs:`, etc.
- Automatic version bumping and changelog generation

---

## 🔗 Resources

- 📖 **[Official Documentation](https://docs.growthbook.io/)**
- 🎯 **[GrowthBook Dashboard](https://app.growthbook.io/)**
- 💬 **[Community Slack](https://slack.growthbook.io/)**
- 🐛 **[Report Issues](https://github.com/growthbook/growthbook-flutter/issues)**
- 📦 **[pub.dev Package](https://pub.dev/packages/growthbook_sdk_flutter)**

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Originally contributed by the team at [Alippo](https://alippo.com/). The core GrowthBook platform remains open-source and free forever.

---

<div align="center">

**Made with ❤️ by the GrowthBook community**

[⭐ Star on GitHub](https://github.com/growthbook/growthbook-flutter) • [🐦 Follow on Twitter](https://twitter.com/growthbook)

</div>
