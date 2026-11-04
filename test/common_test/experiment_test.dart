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

      test('round-trips customFields', () {
        final exp = GBExperiment(
          key: 'exp-cf',
          customFields: {'cfl_abc123': 'My custom field', 'cfl_def456': 42},
        );

        final json = exp.toJson();
        final restored = GBExperiment.fromJson(json);

        expect(restored.customFields, isNotNull);
        expect(restored.customFields!['cfl_abc123'], 'My custom field');
        expect(restored.customFields!['cfl_def456'], 42);
      });

      test('customFields is null when absent', () {
        final exp = GBExperiment(key: 'exp-no-cf');
        final json = exp.toJson();
        final restored = GBExperiment.fromJson(json);

        expect(restored.customFields, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // ranges (BucketRange)
    //
    // A BucketRange is a bare `[start, end]` pair on the wire. Serializing it
    // as an object, or as a 3-element tuple, silently breaks bucketing against
    // every other SDK, so the shape is pinned explicitly here.
    // -------------------------------------------------------------------------
    group('ranges serialization', () {
      test('serialize as 2-element arrays', () {
        final exp = GBExperiment(
          key: 'exp-ranges',
          ranges: [
            [0.0, 0.5],
            [0.5, 1.0],
          ],
        );

        final rawRanges = exp.toJson()['ranges'] as List;

        expect(rawRanges.length, 2);
        expect(rawRanges[0], [0.0, 0.5]);
        expect(rawRanges[1], [0.5, 1.0]);
      });

      test('round-trip preserves values', () {
        final exp = GBExperiment(
          key: 'exp-ranges-rt',
          ranges: [
            [0.0, 0.25],
            [0.25, 0.75],
            [0.75, 1.0],
          ],
        );

        final restored = GBExperiment.fromJson(exp.toJson());

        expect(restored.ranges, isNotNull);
        expect(restored.ranges!.length, 3);
        expect(restored.ranges![0], [0.0, 0.25]);
        expect(restored.ranges![1], [0.25, 0.75]);
        expect(restored.ranges![2], [0.75, 1.0]);
      });

      test('deserialize from raw JSON arrays', () {
        final exp = GBExperiment.fromJson(<String, dynamic>{
          'key': 'exp-raw',
          'ranges': [
            [0.0, 0.5],
            [0.5, 1.0],
          ],
        });

        expect(exp.ranges, isNotNull);
        expect(exp.ranges!.length, 2);
        expect(exp.ranges![0], [0.0, 0.5]);
        expect(exp.ranges![1], [0.5, 1.0]);
      });

      test('emit arrays, never maps or 3-element tuples', () {
        final exp = GBExperiment(
          key: 'exp-shape',
          ranges: [
            [0.0, 0.8]
          ],
        );

        final firstRange = (exp.toJson()['ranges'] as List)[0];

        expect(firstRange, isA<List>(),
            reason: 'BucketRange must be an array, not a map');
        expect((firstRange as List).length, 2,
            reason: 'BucketRange must have exactly 2 elements');
      });
    });

    group('customFields', () {
      test('parsed from JSON map', () {
        final json = <String, dynamic>{
          'key': 'my-experiment',
          'variations': ['control', 'variant'],
          'customFields': {'cfl_abc123': 'My custom field', 'cfl_def456': 42},
        };
        final exp = GBExperiment.fromJson(json);

        expect(exp.customFields, isNotNull);
        expect(exp.customFields!['cfl_abc123'], 'My custom field');
        expect(exp.customFields!['cfl_def456'], 42);
      });

      test('null when not present in JSON', () {
        final json = <String, dynamic>{
          'key': 'my-experiment',
          'variations': []
        };
        final exp = GBExperiment.fromJson(json);

        expect(exp.customFields, isNull);
      });

      test('set via constructor', () {
        final exp = GBExperiment(
          key: 'my-experiment',
          customFields: {'cfl_xyz': 'hello'},
        );

        expect(exp.customFields, isNotNull);
        expect(exp.customFields!['cfl_xyz'], 'hello');
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

      test('contains customFields when set', () {
        final exp = GBExperiment(
          key: 'exp-str',
          customFields: {'cfl_test': 'value'},
        );
        expect(exp.toString(), contains('cfl_test'));
      });

      test('does not throw with all-null optional fields', () {
        final exp = GBExperiment(key: 'min');
        expect(() => exp.toString(), returnsNormally);
      });
    });
  });
}
