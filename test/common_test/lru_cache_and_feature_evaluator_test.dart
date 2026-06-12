import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/Model/gb_parent_condition.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/global_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/options.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/user_context.dart';
import 'package:growthbook_sdk_flutter/src/Network/lru_etag_cache.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _InMemoryCache implements CachingLayer {
  final _store = <String, Uint8List>{};

  @override
  Future<Uint8List?> getContent({required String fileName}) async =>
      _store[fileName];

  @override
  Future<void> saveContent(
          {required String fileName, required Uint8List content}) async =>
      _store[fileName] = content;
}

EvaluationContext _ctx({
  Map<String, dynamic>? features,
  void Function(String, GBFeatureResult)? featureUsageCallback,
  StickyBucketService? stickyBucketService,
  Map<String, dynamic>? forcedVariations,
  Map<String, dynamic>? attributes,
}) =>
    EvaluationContext(
      globalContext: GlobalContext(features: features ?? {}),
      userContext: UserContext(
        attributes: attributes ?? {'id': 'user-1'},
        forcedVariationsMap: forcedVariations ?? {},
      ),
      stackContext: StackContext(),
      options: Options(
        enabled: true,
        isQaMode: false,
        isCacheDisabled: false,
        trackingCallBackWithUser: (_) {},
        featureUsageCallbackWithUser: featureUsageCallback,
        stickyBucketService: stickyBucketService,
      ),
    );

// ---------------------------------------------------------------------------
// LruEtagCache
// ---------------------------------------------------------------------------

void main() {
  group('LruEtagCache', () {
    test('put with null etag removes existing entry', () {
      final cache = LruEtagCache();
      cache.put('http://a.com', '"v1"');
      expect(cache.get('http://a.com'), '"v1"');

      cache.put('http://a.com', null);
      expect(cache.get('http://a.com'), isNull);
    });

    test('contains returns true for stored URL and false for missing', () {
      final cache = LruEtagCache();
      cache.put('http://a.com', '"v1"');
      expect(cache.contains('http://a.com'), isTrue);
      expect(cache.contains('http://b.com'), isFalse);
    });

    test('remove returns the removed value', () {
      final cache = LruEtagCache();
      cache.put('http://a.com', '"v1"');
      final removed = cache.remove('http://a.com');
      expect(removed, '"v1"');
      expect(cache.contains('http://a.com'), isFalse);
    });

    test('clear empties the cache', () {
      final cache = LruEtagCache();
      cache.put('http://a.com', '"v1"');
      cache.put('http://b.com', '"v2"');
      cache.clear();
      expect(cache.size(), 0);
    });

    test('size returns the number of entries', () {
      final cache = LruEtagCache();
      expect(cache.size(), 0);
      cache.put('http://a.com', '"v1"');
      cache.put('http://b.com', '"v2"');
      expect(cache.size(), 2);
    });
  });

  // -------------------------------------------------------------------------
  // FeatureEvaluator
  // -------------------------------------------------------------------------

  group('FeatureEvaluator', () {
    // -----------------------------------------------------------------------
    // Cyclic prerequisite — lines 25 and 67
    // -----------------------------------------------------------------------
    group('cyclic prerequisite', () {
      test('returns cyclicPrerequisite source and triggers featureUsageCallback',
          () {
        // feat-a has parentCondition → feat-b
        // feat-b has parentCondition → feat-a  (creates a cycle)
        final featA = GBFeature(rules: [
          GBFeatureRule(
            parentConditions: [
              GBParentCondition(id: 'feat-b', condition: {'value': true}),
            ],
            force: 'a',
          ),
        ]);
        final featB = GBFeature(rules: [
          GBFeatureRule(
            parentConditions: [
              GBParentCondition(id: 'feat-a', condition: {'value': true}),
            ],
            force: 'b',
          ),
        ]);

        final calls = <String>[];
        final ctx = _ctx(
          features: {'feat-a': featA, 'feat-b': featB},
          featureUsageCallback: (key, _) => calls.add(key),
        );

        final result = FeatureEvaluator().evaluateFeature(ctx, 'feat-a');
        expect(result.source, GBFeatureSource.cyclicPrerequisite);
        expect(calls, isNotEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // Blocked by prerequisite — line 92
    // -----------------------------------------------------------------------
    group('blocked by prerequisite', () {
      test('returns prerequisite source when gate condition fails', () {
        // feat-b returns false (defaultValue)
        // feat-a requires feat-b.value == true (gate: true)
        final featB = GBFeature(defaultValue: false);
        final featA = GBFeature(rules: [
          GBFeatureRule(
            parentConditions: [
              GBParentCondition(
                id: 'feat-b',
                condition: {'value': true},
                gate: true,
              ),
            ],
            force: 'a',
          ),
        ]);

        GBFeatureSource? capturedSource;
        final ctx = _ctx(
          features: {'feat-a': featA, 'feat-b': featB},
          featureUsageCallback: (key, result) {
            if (key == 'feat-a') capturedSource = result.source;
          },
        );

        final result = FeatureEvaluator().evaluateFeature(ctx, 'feat-a');
        expect(result.source, GBFeatureSource.prerequisite);
        expect(capturedSource, GBFeatureSource.prerequisite);
      });
    });

    // -----------------------------------------------------------------------
    // Forced value with stickyBucketService — lines 127 and 155
    // -----------------------------------------------------------------------
    group('forced feature with stickyBucketService', () {
      test('returns forced value and triggers callback, uses fallbackAttribute',
          () {
        final featA = GBFeature(rules: [
          GBFeatureRule(
            force: 'forced',
            coverage: 1.0,
            fallbackAttribute: 'device',
            disableStickyBucketing: false,
          ),
        ]);

        bool callbackCalled = false;
        final svc =
            LocalStorageStickyBucketService(localStorage: _InMemoryCache());
        final ctx = _ctx(
          features: {'feat-a': featA},
          featureUsageCallback: (_, __) => callbackCalled = true,
          stickyBucketService: svc,
        );

        final result = FeatureEvaluator().evaluateFeature(ctx, 'feat-a');
        expect(result.source, GBFeatureSource.force);
        expect(result.value, 'forced');
        expect(callbackCalled, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Experiment result callback — line 195
    // -----------------------------------------------------------------------
    group('experiment result', () {
      test('triggers featureUsageCallback when user is in experiment', () {
        final featA = GBFeature(rules: [
          GBFeatureRule(
            key: 'exp-key',
            variations: ['control', 'treatment'],
            weights: [0.5, 0.5],
            coverage: 1.0,
          ),
        ]);

        bool callbackCalled = false;
        final ctx = _ctx(
          features: {'feat-a': featA},
          featureUsageCallback: (_, __) => callbackCalled = true,
          forcedVariations: {'exp-key': 1},
        );

        final result = FeatureEvaluator().evaluateFeature(ctx, 'feat-a');
        expect(result.source, GBFeatureSource.experiment);
        expect(callbackCalled, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Default value callback — line 203
    // -----------------------------------------------------------------------
    group('default value', () {
      test('triggers featureUsageCallback on default value path', () {
        final featA = GBFeature(defaultValue: 'default');
        bool callbackCalled = false;
        final ctx = _ctx(
          features: {'feat-a': featA},
          featureUsageCallback: (_, __) => callbackCalled = true,
        );

        final result = FeatureEvaluator().evaluateFeature(ctx, 'feat-a');
        expect(result.value, 'default');
        expect(result.source, GBFeatureSource.defaultValue);
        expect(callbackCalled, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // getAttributes — lines 232-245
    // -----------------------------------------------------------------------
    group('getAttributes', () {
      test('returns merged attributes map', () {
        final context = GBContext(
          apiKey: 'key',
          hostURL: 'https://example.com',
          attributes: {'id': 'user-1', 'plan': 'pro'},
          enabled: true,
          forcedVariation: {},
          qaMode: false,
          trackingCallBack: (_) {},
        );
        final result = FeatureEvaluator().getAttributes(context);
        expect(result['id'], 'user-1');
        expect(result['plan'], 'pro');
      });

      test('returns empty map when attributes is null', () {
        final context = GBContext(
          apiKey: 'key',
          hostURL: 'https://example.com',
          enabled: true,
          forcedVariation: {},
          qaMode: false,
          trackingCallBack: (_) {},
        );
        final result = FeatureEvaluator().getAttributes(context);
        expect(result, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // FeatureEvalContext constructor — lines 254-257
    // -----------------------------------------------------------------------
    group('FeatureEvalContext', () {
      test('initialises with defaults', () {
        final ctx = FeatureEvalContext();
        expect(ctx.id, isNull);
        expect(ctx.evaluatedFeatures, isEmpty);
      });

      test('initialises with provided values', () {
        final ctx = FeatureEvalContext(
          id: 'feat-a',
          evaluatedFeatures: {'feat-b'},
        );
        expect(ctx.id, 'feat-a');
        expect(ctx.evaluatedFeatures, contains('feat-b'));
      });
    });
  });
}
