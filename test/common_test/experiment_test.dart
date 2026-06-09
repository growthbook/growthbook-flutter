import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

void main() {
  group('GBExperiment', () {
    // -------------------------------------------------------------------------
    // deactivated getter
    // -------------------------------------------------------------------------
    group('deactivated', () {
      test('returns false when active is true', () {
        final exp = GBExperiment(key: 'exp', active: true);
        expect(exp.deactivated, isFalse);
      });

      test('returns true when active is false', () {
        final exp = GBExperiment(key: 'exp', active: false);
        expect(exp.deactivated, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // fromJson / toJson round-trip
    // -------------------------------------------------------------------------
    group('toJson / fromJson', () {
      test('round-trips a minimal experiment', () {
        final exp = GBExperiment(key: 'my-exp');
        final json = exp.toJson();
        expect(json['key'], 'my-exp');

        final restored = GBExperiment.fromJson(json);
        expect(restored.key, 'my-exp');
        expect(restored.active, isTrue);
      });

      test('round-trips all scalar fields', () {
        final exp = GBExperiment(
          key: 'full-exp',
          active: false,
          coverage: 0.5,
          force: 1,
          hashVersion: 2,
          disableStickyBucketing: true,
          bucketVersion: 3,
          minBucketVersion: 1,
          seed: 'abc',
          name: 'Full experiment',
          phase: '1',
          hashAttribute: 'id',
          fallbackAttribute: 'device',
          weights: [0.5, 0.5],
        );

        final json = exp.toJson();
        final restored = GBExperiment.fromJson(json);

        expect(restored.key, 'full-exp');
        expect(restored.active, isFalse);
        expect(restored.coverage, 0.5);
        expect(restored.force, 1);
        expect(restored.hashVersion, 2);
        expect(restored.disableStickyBucketing, isTrue);
        expect(restored.bucketVersion, 3);
        expect(restored.minBucketVersion, 1);
        expect(restored.seed, 'abc');
        expect(restored.name, 'Full experiment');
        expect(restored.phase, '1');
        expect(restored.hashAttribute, 'id');
        expect(restored.fallbackAttribute, 'device');
        expect(restored.weights, [0.5, 0.5]);
      });
    });

    // -------------------------------------------------------------------------
    // toString
    // -------------------------------------------------------------------------
    group('toString', () {
      test('contains key fields', () {
        final exp = GBExperiment(
          key: 'exp-str',
          active: true,
          coverage: 0.8,
          seed: 'seed-val',
          name: 'My Exp',
          phase: '2',
          hashAttribute: 'user',
          fallbackAttribute: 'device',
          disableStickyBucketing: false,
        );
        final str = exp.toString();

        expect(str, contains('true'));
        expect(str, contains('0.8'));
        expect(str, contains('seed-val'));
        expect(str, contains('My Exp'));
        expect(str, contains('2'));
        expect(str, contains('user'));
        expect(str, contains('device'));
        expect(str, contains('false'));
      });

      test('does not throw with all-null optional fields', () {
        final exp = GBExperiment(key: 'min');
        expect(() => exp.toString(), returnsNormally);
      });
    });
  });
}
