import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/global_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/options.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/user_context.dart';

import '../mocks/network_mock.dart';

/// Covers replacing the tracking and feature usage callbacks after the SDK has
/// been built.
///
/// The builder callback is enough when the analytics sink exists at startup.
/// Often it does not: it appears after a tracking-consent prompt, after login,
/// or once a third-party SDK finishes starting. These tests pin that a sink
/// installed later actually receives events, and that the one it replaced stops
/// receiving them.
void main() {
  group('GrowthBookSDK — runtime callbacks', () {
    const testApiKey = '<API_KEY>';
    const testHostURL = 'https://example.growthbook.io';
    const client = MockNetworkClient();
    final cachingManager = CachingManager();

    Future<GrowthBookSDK> buildSdk({
      TrackingCallBack? trackingCallBack,
      GBFeatureUsageCallback? featureUsageCallback,
    }) async {
      final builder = GBSDKBuilderApp(
        apiKey: testApiKey,
        hostURL: testHostURL,
        attributes: {'id': 'user-1'},
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

    // Exposures are deduped per SDK instance, so a test that evaluates the
    // same experiment twice is measuring the dedupe unless it means to.
    GBExperiment experimentNamed(String key) =>
        GBExperiment(key: key, variations: [0, 1]);

    group('setTrackingCallback', () {
      test('the builder callback is the sink until one is installed', () async {
        final builderSink = <String>[];
        final sdk = await buildSdk(
          trackingCallBack: (data) => builderSink.add(data.experiment.key),
        );

        sdk.run(experimentNamed('runtime-default-sink'));

        expect(builderSink, ['runtime-default-sink']);
      });

      test('an installed callback receives subsequent exposures', () async {
        final builderSink = <String>[];
        final runtimeSink = <String>[];
        final sdk = await buildSdk(
          trackingCallBack: (data) => builderSink.add(data.experiment.key),
        );

        sdk.setTrackingCallback((data) => runtimeSink.add(data.experiment.key));
        sdk.run(experimentNamed('runtime-installed-sink'));

        expect(runtimeSink, ['runtime-installed-sink']);
        expect(builderSink, isEmpty,
            reason: 'the replaced callback must stop receiving exposures');
      });

      // The evaluation context is built once and reused, so a stale one would
      // keep firing into the sink captured when it was built — the failure this
      // is really guarding against.
      test('the replacement applies after an evaluation has already run',
          () async {
        final builderSink = <String>[];
        final runtimeSink = <String>[];
        final sdk = await buildSdk(
          trackingCallBack: (data) => builderSink.add(data.experiment.key),
        );

        sdk.run(experimentNamed('runtime-first'));
        expect(builderSink, ['runtime-first']);

        sdk.setTrackingCallback((data) => runtimeSink.add(data.experiment.key));
        sdk.run(experimentNamed('runtime-second'));

        expect(runtimeSink, ['runtime-second'],
            reason: 'a cached evaluation context must not pin the old sink');
        expect(builderSink, ['runtime-first'],
            reason: 'the first exposure stays with the sink that received it');
      });

      test('the last installed callback wins', () async {
        final first = <String>[];
        final second = <String>[];
        final sdk = await buildSdk();

        sdk.setTrackingCallback((data) => first.add(data.experiment.key));
        sdk.setTrackingCallback((data) => second.add(data.experiment.key));
        sdk.run(experimentNamed('runtime-last-wins'));

        expect(second, ['runtime-last-wins']);
        expect(first, isEmpty);
      });

      test('the installed callback is readable from the context', () async {
        // Consumers wrap rather than replace, and reading the current sink to
        // chain to it is the documented way to do that.
        final sdk = await buildSdk();
        void sink(GBTrackData data) {}

        sdk.setTrackingCallback(sink);

        expect(sdk.context.trackingCallBack, same(sink));
      });

      test('a throwing installed callback does not break run()', () async {
        final sdk = await buildSdk();

        sdk.setTrackingCallback((_) => throw StateError('analytics not ready'));
        final result = sdk.run(experimentNamed('runtime-installed-throws'));

        expect(result.inExperiment, isTrue);
      });

      test('it reaches the feature evaluation path too', () async {
        final runtimeSink = <String>[];
        final sdk = await buildSdk();

        sdk.setTrackingCallback((data) => runtimeSink.add(data.experiment.key));
        // Matches the condition on the `onboarding` rule in the mock payload,
        // so the feature resolves through an experiment.
        sdk.setAttributes({'id': '2435245', 'loggedIn': false});
        final result = sdk.feature('onboarding');

        expect(result.source, GBFeatureSource.experiment);
        expect(runtimeSink, ['onboarding']);
      });
    });

    group('setFeatureUsageCallback', () {
      test('an installed callback receives subsequent evaluations', () async {
        final seen = <String>[];
        final sdk = await buildSdk();

        sdk.setFeatureUsageCallback((key, _) => seen.add(key));
        sdk.feature('onboarding');

        expect(seen, ['onboarding']);
      });

      test('it replaces a callback supplied to the builder', () async {
        final builderSink = <String>[];
        final runtimeSink = <String>[];
        final sdk = await buildSdk(
          featureUsageCallback: (key, _) => builderSink.add(key),
        );

        sdk.feature('onboarding');
        expect(builderSink, ['onboarding']);

        sdk.setFeatureUsageCallback((key, _) => runtimeSink.add(key));
        sdk.feature('qrscanpayment');

        expect(runtimeSink, ['qrscanpayment']);
        expect(builderSink, ['onboarding'],
            reason: 'the replaced callback must stop receiving evaluations');
      });

      test('it applies to evalFeature() as well', () async {
        final seen = <String>[];
        final sdk = await buildSdk();

        sdk.setFeatureUsageCallback((key, _) => seen.add(key));
        sdk.evalFeature('editprofile');

        expect(seen, ['editprofile']);
      });

      test('the installed callback is readable from the context', () async {
        final sdk = await buildSdk();
        void sink(String key, GBFeatureResult result) {}

        sdk.setFeatureUsageCallback(sink);

        expect(sdk.context.featureUsageCallback, same(sink));
      });

      test('the last installed callback wins', () async {
        final first = <String>[];
        final second = <String>[];
        final sdk = await buildSdk();

        sdk.setFeatureUsageCallback((key, _) => first.add(key));
        sdk.setFeatureUsageCallback((key, _) => second.add(key));
        sdk.feature('onboarding');

        expect(second, ['onboarding']);
        expect(first, isEmpty);
      });

      test('a throwing installed callback does not break feature()', () async {
        final sdk = await buildSdk();

        sdk.setFeatureUsageCallback(
            (_, __) => throw StateError('sink disposed'));
        final result = sdk.feature('onboarding');

        expect(result.value, isNotNull);
      });
    });

    group('installing a callback leaves the rest of the context alone', () {
      test('attributes and features survive a tracking callback swap',
          () async {
        final sdk = await buildSdk();
        sdk.setAttributes({'id': 'user-7', 'plan': 'pro'});

        sdk.setTrackingCallback((_) {});

        expect(sdk.context.attributes, {'id': 'user-7', 'plan': 'pro'});
        expect(sdk.feature('onboarding').value, isNotNull);
      });
    });

    group('an exposure nobody received', () {
      /// Marking an exposure as reported when there is no sink loses it for
      /// good: unlike the JavaScript SDK there is no deferred buffer for
      /// `setTrackingCallback` to flush, so the only way a later sink can see
      /// it is for the exposure to stay unmarked.
      test('reaches a callback installed afterwards, exactly once', () {
        final seen = <String>[];
        final context = EvaluationContext(
          globalContext: GlobalContext(features: {}),
          userContext: UserContext(
            attributes: {'id': 'user-1'},
            forcedVariationsMap: {},
          ),
          stackContext: StackContext(),
          options: Options(
            enabled: true,
            isQaMode: false,
            isCacheDisabled: false,
          ),
        );
        final experiment = experimentNamed('runtime-no-sink');

        ExperimentEvaluator().evaluateExperiment(context, experiment);
        expect(seen, isEmpty, reason: 'nothing was listening yet');

        context.options.trackingCallBackWithUser =
            (data) => seen.add(data.experiment.key);
        ExperimentEvaluator().evaluateExperiment(context, experiment);
        ExperimentEvaluator().evaluateExperiment(context, experiment);

        expect(seen, ['runtime-no-sink']);
      });
    });
  });
}
