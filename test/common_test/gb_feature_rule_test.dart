import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

void main() {
  group('GBFeatureRule bucket range serialization', () {
    test('range serializes as 2-element array', () {
      final rule = GBFeatureRule(range: [0.0, 0.5]);

      final json = rule.toJson();

      expect(json['range'], isA<List>());
      expect(json['range'], [0.0, 0.5]);
    });

    test('ranges serialize as list of 2-element arrays', () {
      final rule = GBFeatureRule(
        ranges: [
          [0.0, 0.5],
          [0.5, 1.0],
        ],
      );

      final json = rule.toJson();

      expect(json['ranges'], isA<List>());
      final rawRanges = json['ranges'] as List;
      expect(rawRanges.length, 2);
      expect(rawRanges[0], [0.0, 0.5]);
      expect(rawRanges[1], [0.5, 1.0]);
    });

    test('range round-trips correctly', () {
      final rule = GBFeatureRule(range: [0.2, 0.8]);

      final restored = GBFeatureRule.fromJson(rule.toJson());

      expect(restored.range, isNotNull);
      expect(restored.range, [0.2, 0.8]);
    });

    test('ranges round-trip preserves all values', () {
      final rule = GBFeatureRule(
        ranges: [
          [0.0, 0.33],
          [0.33, 0.66],
          [0.66, 1.0],
        ],
      );

      final restored = GBFeatureRule.fromJson(rule.toJson());

      expect(restored.ranges, isNotNull);
      expect(restored.ranges!.length, 3);
      expect(restored.ranges![0], [0.0, 0.33]);
      expect(restored.ranges![1], [0.33, 0.66]);
      expect(restored.ranges![2], [0.66, 1.0]);
    });

    test('ranges deserialized from raw JSON as 2-element arrays', () {
      final json = <String, dynamic>{
        'ranges': [
          [0.0, 0.5],
          [0.5, 1.0],
        ],
      };

      final rule = GBFeatureRule.fromJson(json);

      expect(rule.ranges, isNotNull);
      expect(rule.ranges!.length, 2);
      expect(rule.ranges![0], [0.0, 0.5]);
      expect(rule.ranges![1], [0.5, 1.0]);
    });

    test('range array has exactly 2 elements, not 3', () {
      final rule = GBFeatureRule(range: [0.0, 1.0]);

      final json = rule.toJson();
      final rawRange = json['range'] as List;

      expect(rawRange.length, 2,
          reason: 'BucketRange must be a 2-element [start, end] array');
    });

    test('GBFeature with rules containing ranges round-trips correctly', () {
      final feature = GBFeature(
        rules: [
          GBFeatureRule(
            key: 'my-exp',
            ranges: [
              [0.0, 0.5],
              [0.5, 1.0],
            ],
          ),
        ],
      );

      // Use jsonEncode/jsonDecode to ensure deep conversion of nested objects.
      final json =
          jsonDecode(jsonEncode(feature.toJson())) as Map<String, dynamic>;
      final restored = GBFeature.fromJson(json);

      expect(restored.rules, isNotNull);
      expect(restored.rules!.length, 1);
      expect(restored.rules![0].ranges, isNotNull);
      expect(restored.rules![0].ranges![0], [0.0, 0.5]);
      expect(restored.rules![0].ranges![1], [0.5, 1.0]);
    });
  });
}
