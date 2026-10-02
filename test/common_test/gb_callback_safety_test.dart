import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';

import '../mocks/network_mock.dart';

/// Covers the callbacks the host app supplies — the tracking callback and the
/// feature usage callback — throwing out of evaluation.
///
/// They are consumer code: an analytics SDK that is not initialised yet, a sink
/// torn down while a widget was disposing. Before the guard, one of those
/// taking `feature()` or `run()` down with it was the documented behaviour by
/// omission.
void main() {
  group('GrowthBookSDK — callback safety', () {
    const testApiKey = '<API_KEY>';
    const testHostURL = 'https://example.growthbook.io';
    const client = MockNetworkClient();
    final cachingManager = CachingManager();

    // Matches the condition on the `onboarding` rule in the mock payload, so
    // the feature resolves through an experiment instead of its default value.
    const onboardingExperimentAttributes = {
      'id': '2435245',
      'loggedIn': false,
    };

    Future<GrowthBookSDK> buildSdk({
      TrackingCallBack? trackingCallBack,
      GBFeatureUsageCallback? featureUsageCallback,
      Map<String, dynamic>? attributes,
    }) async {
      final builder = GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: attributes ?? {'id': 'user-1'},
        client: client,
        growthBookTrackingCallBack: trackingCallBack ?? (_) {},
        backgroundSync: false,
      );
      if (featureUsageCallback != null) {
        builder.setFeatureUsageCallback(featureUsageCallback);
      }
      return builder.initialize();
    }

    tearDown(() {
      cachingManager.clearCache();
    });

    // `ExperimentHelper.shared` dedupes exposures in a process-wide set, so
    // every test needs its own experiment key — a reused one silences the
    // callback and the assertion would be measuring the dedupe instead.
    GBExperiment experimentNamed(String key) =>
        GBExperiment(key: key, variations: [0, 1]);

    group('tracking callback', () {
      test('a throwing callback does not break run()', () async {
        final sdk = await buildSdk(
          trackingCallBack: (_) => throw StateError('analytics not ready'),
        );

        final result = sdk.run(experimentNamed('safety-run-throws'));

        expect(result.inExperiment, isTrue);
      });

      test('a throwing callback does not stop later exposures', () async {
        var calls = 0;
        final sdk = await buildSdk(trackingCallBack: (_) {
          calls++;
          throw StateError('analytics not ready');
        });

        sdk.run(experimentNamed('safety-run-first'));
        sdk.run(experimentNamed('safety-run-second'));

        expect(calls, 2);
      });

      test('a throwing callback does not break feature()', () async {
        var calls = 0;
        final sdk = await buildSdk(
          attributes: onboardingExperimentAttributes,
          trackingCallBack: (_) {
            calls++;
            throw StateError('analytics not ready');
          },
        );

        final result = sdk.feature('onboarding');

        expect(calls, 1, reason: 'the feature must resolve via an experiment');
        expect(result.source, GBFeatureSource.experiment);
      });
    });

    group('feature usage callback', () {
      test('a throwing callback does not break feature()', () async {
        final sdk = await buildSdk(
          featureUsageCallback: (_, __) => throw StateError('sink disposed'),
        );

        final result = sdk.feature('onboarding');

        expect(result.value, isNotNull);
      });

      test('a throwing callback does not break evalFeature()', () async {
        final sdk = await buildSdk(
          featureUsageCallback: (_, __) => throw StateError('sink disposed'),
        );

        final result = sdk.evalFeature('onboarding');

        expect(result.value, isNotNull);
      });

      test('a throwing callback still fires for the next feature', () async {
        final seen = <String>[];
        final sdk = await buildSdk(featureUsageCallback: (key, _) {
          seen.add(key);
          throw StateError('sink disposed');
        });

        sdk.feature('onboarding');
        sdk.feature('qrscanpayment');

        expect(seen, ['onboarding', 'qrscanpayment']);
      });

      test('an unknown feature reports usage without breaking', () async {
        final seen = <String>[];
        final sdk = await buildSdk(featureUsageCallback: (key, _) {
          seen.add(key);
          throw StateError('sink disposed');
        });

        final result = sdk.feature('no-such-feature');

        expect(result.source, GBFeatureSource.unknownFeature);
        expect(seen, ['no-such-feature']);
      });
    });

    group('missing tracking callback', () {
      test('evaluation runs when the context has no tracking callback',
          () async {
        // `GBContext` takes the callback as optional, so a caller assembling
        // one directly — or clearing it afterwards — leaves evaluation without
        // a sink. It used to be force-unwrapped on the way into the evaluation
        // context.
        final context = GBContext(
          apiKey: testApiKey,
          hostURL: testHostURL,
          enabled: true,
          attributes: {'id': 'user-1'},
          features: {
            'solo': GBFeature(defaultValue: 'on'),
          },
        );

        final evaluationContext = GBUtils.initializeEvalContext(context, null);
        final result =
            FeatureEvaluator().evaluateFeature(evaluationContext, 'solo');

        expect(result.value, 'on');
      });
    });
  });
}
