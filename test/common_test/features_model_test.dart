import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

void main() {
  // -------------------------------------------------------------------------
  // GBFeatureRule — toString
  // -------------------------------------------------------------------------
  group('GBFeatureRule', () {
    group('toString', () {
      test('does not throw with all-null optional fields', () {
        final rule = GBFeatureRule();
        expect(() => rule.toString(), returnsNormally);
      });

      test('contains populated field values', () {
        final rule = GBFeatureRule(
          id: 'rule-1',
          coverage: 0.6,
          force: 'value-a',
          key: 'exp-key',
          hashAttribute: 'id',
          fallbackAttribute: 'device',
          hashVersion: 2,
          disableStickyBucketing: true,
          bucketVersion: 1,
          minBucketVersion: 0,
          seed: 'my-seed',
          name: 'My Rule',
          phase: '3',
        );
        final str = rule.toString();

        expect(str, contains('rule-1'));
        expect(str, contains('0.6'));
        expect(str, contains('value-a'));
        expect(str, contains('exp-key'));
        expect(str, contains('id'));
        expect(str, contains('device'));
        expect(str, contains('2'));
        expect(str, contains('true'));
        expect(str, contains('my-seed'));
        expect(str, contains('My Rule'));
        expect(str, contains('3'));
      });
    });

    group('toJson / fromJson', () {
      test('round-trips a minimal rule', () {
        final rule = GBFeatureRule(id: 'r1', coverage: 0.5);
        final json = rule.toJson();
        final restored = GBFeatureRule.fromJson(json);
        expect(restored.id, 'r1');
        expect(restored.coverage, 0.5);
      });
    });
  });

  // -------------------------------------------------------------------------
  // GBFeatureResult — fromJson / toJson
  // -------------------------------------------------------------------------
  group('GBFeatureResult', () {
    group('toJson / fromJson', () {
      test('round-trips a minimal result', () {
        final result = GBFeatureResult(
          value: 'hello',
          on: true,
          off: false,
          source: GBFeatureSource.force,
        );
        final json = result.toJson();
        expect(json['value'], 'hello');
        expect(json['on'], isTrue);

        final restored = GBFeatureResult.fromJson(json);
        expect(restored.value, 'hello');
        expect(restored.on, isTrue);
        expect(restored.off, isFalse);
        expect(restored.source, GBFeatureSource.force);
      });

      test('round-trips a result with default values', () {
        final result = GBFeatureResult();
        final json = result.toJson();
        final restored = GBFeatureResult.fromJson(json);
        expect(restored.on, isFalse);
        expect(restored.off, isTrue);
        expect(restored.value, isNull);
      });
    });
  });
}
