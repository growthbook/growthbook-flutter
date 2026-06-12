import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/gb_parent_condition.dart';
import 'package:growthbook_sdk_flutter/src/Model/remote_eval_model.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_variation_meta.dart';

void main() {
  // -------------------------------------------------------------------------
  // GBExperimentResult
  // -------------------------------------------------------------------------
  group('GBExperimentResult', () {
    group('fromJson / toJson', () {
      test('round-trips basic fields', () {
        final result = GBExperimentResult(
          inExperiment: true,
          key: '1',
          variationID: 1,
          value: 'blue',
          bucket: 0.42,
          featureId: 'feat-a',
          hashAttribute: 'id',
          hashUsed: true,
          hashValue: 'user-1',
          stickyBucketUsed: false,
          name: 'Variation B',
          passthrough: false,
        );

        final json = result.toJson();
        final restored = GBExperimentResult.fromJson(json);

        expect(restored.inExperiment, isTrue);
        expect(restored.key, '1');
        expect(restored.variationID, 1);
        expect(restored.value, 'blue');
        expect(restored.bucket, 0.42);
        expect(restored.featureId, 'feat-a');
        expect(restored.hashAttribute, 'id');
        expect(restored.hashUsed, isTrue);
        expect(restored.hashValue, 'user-1');
        expect(restored.stickyBucketUsed, isFalse);
        expect(restored.name, 'Variation B');
        expect(restored.passthrough, isFalse);
      });

      test('_toStringValue converts non-string hashValue to string', () {
        final json = {
          'inExperiment': true,
          'key': 0,
          'hashValue': 12345,
        };
        final result = GBExperimentResult.fromJson(json);
        expect(result.hashValue, '12345');
      });

      test('_toStringValue returns null for null hashValue', () {
        final json = {
          'inExperiment': false,
          'key': '0',
          'hashValue': null,
        };
        final result = GBExperimentResult.fromJson(json);
        expect(result.hashValue, isNull);
      });

      test('_toStringRequired converts int key to string', () {
        final json = {'inExperiment': false, 'key': 42};
        final result = GBExperimentResult.fromJson(json);
        expect(result.key, '42');
      });
    });
  });

  // -------------------------------------------------------------------------
  // GBVariationMeta
  // -------------------------------------------------------------------------
  group('GBVariationMeta', () {
    group('toJson / fromJson', () {
      test('round-trips all fields', () {
        final meta = GBVariationMeta(key: 'v1', name: 'Control', passthrough: true);
        final json = meta.toJson();
        final restored = GBVariationMeta.fromJson(json);

        expect(restored.key, 'v1');
        expect(restored.name, 'Control');
        expect(restored.passthrough, isTrue);
      });
    });

    group('toString', () {
      test('contains all field values', () {
        final meta = GBVariationMeta(key: 'v2', name: 'Treatment', passthrough: false);
        final str = meta.toString();
        expect(str, contains('v2'));
        expect(str, contains('Treatment'));
        expect(str, contains('false'));
      });

      test('does not throw with null fields', () {
        final meta = GBVariationMeta();
        expect(() => meta.toString(), returnsNormally);
      });
    });
  });

  // -------------------------------------------------------------------------
  // GBTrack
  // -------------------------------------------------------------------------
  group('GBTrack', () {
    group('toJson / fromJson', () {
      test('round-trips with null fields', () {
        final track = GBTrack();
        final json = track.toJson();
        final restored = GBTrack.fromJson(json);
        expect(restored.experiment, isNull);
        expect(restored.result, isNull);
      });
    });

    group('toString', () {
      test('does not throw with null fields', () {
        final track = GBTrack();
        expect(() => track.toString(), returnsNormally);
      });

      test('contains experiment and result labels', () {
        final track = GBTrack();
        final str = track.toString();
        expect(str, contains('experiment'));
        expect(str, contains('result'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // RemoteEvalModel
  // -------------------------------------------------------------------------
  group('RemoteEvalModel', () {
    group('fromJson / toJson', () {
      test('round-trips all fields', () {
        final model = RemoteEvalModel(
          attributes: {'id': 'user-1'},
          forcedFeatures: ['feat-a'],
          forcedVariations: {'exp-1': 0},
        );
        final json = model.toJson();
        final restored = RemoteEvalModel.fromJson(json);

        expect(restored.attributes, {'id': 'user-1'});
        expect(restored.forcedFeatures, ['feat-a']);
        expect(restored.forcedVariations, {'exp-1': 0});
      });

      test('fromJson handles null fields', () {
        final restored = RemoteEvalModel.fromJson({});
        expect(restored.attributes, isNull);
        expect(restored.forcedFeatures, isNull);
        expect(restored.forcedVariations, isNull);
      });
    });
  });

  // -------------------------------------------------------------------------
  // GBParentCondition
  // -------------------------------------------------------------------------
  group('GBParentCondition', () {
    group('toJson / fromJson', () {
      test('round-trips all fields', () {
        final cond = GBParentCondition(
          id: 'parent-feat',
          condition: {'value': true},
          gate: true,
        );
        final json = cond.toJson();
        final restored = GBParentCondition.fromJson(json);

        expect(restored.id, 'parent-feat');
        expect(restored.condition, {'value': true});
        expect(restored.gate, isTrue);
      });

      test('round-trips with null gate', () {
        final cond = GBParentCondition(id: 'feat', condition: {});
        final json = cond.toJson();
        final restored = GBParentCondition.fromJson(json);
        expect(restored.gate, isNull);
      });
    });
  });
}
