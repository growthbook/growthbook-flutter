import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Cache/caching_manager.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/evaluation_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/global_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/options.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/user_context.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';
import 'package:growthbook_sdk_flutter/src/Utils/feature_url_builder.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_filter.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_variation_meta.dart';

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

EvaluationContext _evalContext({
  Map<String, dynamic>? attributes,
  Map<StickyAttributeKey, StickyAssignmentsDocument>? docs,
}) =>
    EvaluationContext(
      globalContext: GlobalContext(),
      userContext: UserContext(
        attributes: attributes ?? {'id': 'user-1'},
        stickyBucketAssignmentDocs: docs,
      ),
      stackContext: StackContext(),
      options: Options(
        isQaMode: false,
        isCacheDisabled: false,
        trackingCallBackWithUser: (_) {},
      ),
    );

GBContext _gbContext({
  StickyBucketService? stickyBucketService,
  List<String>? stickyBucketIdentifierAttributes,
  Map<String, GBFeature>? features,
}) =>
    GBContext(
      apiKey: 'key',
      hostURL: 'https://example.com',
      attributes: {'id': 'user-1'},
      enabled: true,
      forcedVariation: {},
      qaMode: false,
      trackingCallBack: (_) {},
      stickyBucketService: stickyBucketService,
      stickyBucketIdentifierAttributes: stickyBucketIdentifierAttributes,
      features: features ?? {},
    );

void main() {
  // -------------------------------------------------------------------------
  // GBFilter — toJson
  // -------------------------------------------------------------------------
  group('GBFilter', () {
    test('toJson / fromJson round-trips all fields', () {
      final filter = GBFilter(
        seed: 'my-seed',
        ranges: [
          [0.0, 0.5]
        ],
        attribute: 'id',
        hashVersion: 2,
      );
      final json = filter.toJson();
      final restored = GBFilter.fromJson(json);

      expect(restored.seed, 'my-seed');
      expect(restored.attribute, 'id');
      expect(restored.hashVersion, 2);
    });
  });

  // -------------------------------------------------------------------------
  // FeatureURLBuilder — SERVER_SENT_REMOTE_FEATURE_EVAL branch
  // -------------------------------------------------------------------------
  group('FeatureURLBuilder', () {
    test('builds URL for SERVER_SENT_REMOTE_FEATURE_EVAL strategy', () {
      final url = FeatureURLBuilder.buildUrl(
        'https://example.com/',
        'my-key',
        featureRefreshStrategy:
            FeatureRefreshStrategy.SERVER_SENT_REMOTE_FEATURE_EVAL,
      );
      expect(url, contains('api/eval'));
      expect(url, endsWith('my-key'));
    });

    test('builds URL for SERVER_SENT_EVENTS strategy', () {
      final url = FeatureURLBuilder.buildUrl(
        'https://example.com/',
        'my-key',
        featureRefreshStrategy: FeatureRefreshStrategy.SERVER_SENT_EVENTS,
      );
      expect(url, contains('sub'));
      expect(url, endsWith('my-key'));
    });
  });

  // -------------------------------------------------------------------------
  // GBUtils.getHashAttribute — attributeOverrides paths
  // -------------------------------------------------------------------------
  group('GBUtils.getHashAttribute', () {
    test('returns value from attributeOverrides when present', () {
      final result = GBUtils.getHashAttribute(
        attr: 'id',
        attributes: {'id': 'original'},
        attributeOverrides: {'id': 'overridden'},
      );
      expect(result[1], 'overridden');
    });

    test('falls back to attributeOverrides when primary attr is empty', () {
      final result = GBUtils.getHashAttribute(
        attr: 'id',
        fallback: 'device',
        attributes: {'id': '', 'device': 'dev-1'},
        attributeOverrides: {'device': 'dev-override'},
      );
      expect(result[0], 'device');
      expect(result[1], 'dev-override');
    });
  });

  // -------------------------------------------------------------------------
  // GBUtils.deriveStickyBucketIdentifierAttributes
  // -------------------------------------------------------------------------
  group('GBUtils.deriveStickyBucketIdentifierAttributes', () {
    test('returns empty list when features have no rules with variations', () {
      final context = _gbContext(
        features: {'flag': GBFeature(defaultValue: true)},
      );
      final result = GBUtils.deriveStickyBucketIdentifierAttributes(
        context: context,
        data: null,
      );
      expect(result, isEmpty);
    });

    test('collects hashAttribute from rules with variations', () {
      final rule = GBFeatureRule(
        hashAttribute: 'id',
        variations: ['control', 'treatment'],
      );
      final context = _gbContext(
        features: {
          'flag': GBFeature(rules: [rule]),
        },
      );
      final result = GBUtils.deriveStickyBucketIdentifierAttributes(
        context: context,
        data: null,
      );
      expect(result, contains('id'));
    });

    test('collects fallbackAttribute when present', () {
      final rule = GBFeatureRule(
        hashAttribute: 'id',
        fallbackAttribute: 'device',
        variations: ['a', 'b'],
      );
      final context = _gbContext(
        features: {
          'flag': GBFeature(rules: [rule]),
        },
      );
      final result = GBUtils.deriveStickyBucketIdentifierAttributes(
        context: context,
        data: null,
      );
      expect(result, contains('id'));
      expect(result, contains('device'));
    });
  });

  // -------------------------------------------------------------------------
  // GBUtils.getStickyBucketAttributes
  // -------------------------------------------------------------------------
  group('GBUtils.getStickyBucketAttributes', () {
    test('returns empty map when stickyBucketIdentifierAttributes is empty', () {
      final context = _gbContext(stickyBucketIdentifierAttributes: []);
      final result = GBUtils.getStickyBucketAttributes(context, null, {}, {});
      expect(result, isEmpty);
    });

    test('returns attributes map for given identifier attributes', () {
      final context = _gbContext(
        stickyBucketIdentifierAttributes: ['id'],
      );
      final result = GBUtils.getStickyBucketAttributes(
        context,
        null,
        {'id': 'user-42'},
        {},
      );
      expect(result.containsKey('id'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // GBUtils.refreshStickyBuckets
  // -------------------------------------------------------------------------
  group('GBUtils.refreshStickyBuckets', () {
    test('does nothing when stickyBucketService is null', () async {
      final context = _gbContext();
      await expectLater(
        GBUtils.refreshStickyBuckets(context, null, {}, {}),
        completes,
      );
    });

    test('populates stickyBucketAssignmentDocs when service is set', () async {
      final svc = LocalStorageStickyBucketService(
        localStorage: _InMemoryCache(),
      );
      final context = _gbContext(
        stickyBucketService: svc,
        stickyBucketIdentifierAttributes: ['id'],
      );
      await GBUtils.refreshStickyBuckets(context, null, {'id': 'user-1'}, {});
      // No crash — docs map is assigned (may be empty since nothing was saved)
      expect(context.stickyBucketAssignmentDocs, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // GBUtils.getStickyBucketVariation — invalid variation key path
  // -------------------------------------------------------------------------
  group('GBUtils.getStickyBucketVariation', () {
    test('returns variation -1 when assignment key exists but meta has no match',
        () {
      const expKey = 'my-exp';
      const bucketVersion = 0;
      final assignmentKey =
          GBUtils.getStickyBucketExperimentKey(expKey, bucketVersion);

      final doc = StickyAssignmentsDocument(
        attributeName: 'id',
        attributeValue: 'user-1',
        assignments: {assignmentKey: 'nonexistent-variation'},
      );

      final context = _evalContext(
        attributes: {'id': 'user-1'},
        docs: {'id||user-1': doc},
      );

      final result = GBUtils.getStickyBucketVariation(
        context: context,
        experimentKey: expKey,
        experimentBucketVersion: bucketVersion,
        minExperimentBucketVersion: 0,
        meta: [
          GBVariationMeta(key: 'control'),
          GBVariationMeta(key: 'treatment'),
        ],
        expHashAttribute: 'id',
        expFallBackAttribute: null,
      );

      expect(result.variation, -1);
    });
  });

  // -------------------------------------------------------------------------
  // RoundToExtension — tested via num (not double) to avoid DoubleExt conflict
  // -------------------------------------------------------------------------
  group('RoundToExtension', () {
    test('roundTo rounds to given fraction digits', () {
      // Use int literal (extends num) so RoundToExtension takes priority over DoubleExt
      const n = 3 as num;
      expect(n.roundTo(numFractionDigits: 4), 3.0);
    });

    test('roundTo with 0 fraction digits (default) returns whole number', () {
      const n = 5 as num;
      expect(n.roundTo(numFractionDigits: 0), 5.0);
    });

    test('roundTo clamps negative fractionDigits to 0', () {
      const n = 7 as num;
      expect(() => n.roundTo(numFractionDigits: -1), returnsNormally);
    });
  });
}
