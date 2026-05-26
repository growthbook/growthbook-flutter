import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';

import '../Helper/gb_test_helper.dart';

bool _docsEqual(
  Map<String, StickyAssignmentsDocument> a,
  Map<String, StickyAssignmentsDocument> b,
) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    if (a[key].toString() != b[key].toString()) return false;
  }
  return true;
}

void main() {
  group('GBStickyBucketingFeatureTests', () {
    late List<dynamic> evalConditions;

    setUp(() {
      evalConditions = GBTestHelper.getStickyBucketingData();
    });

    test('testEvaluateFeatureWithStickyBucketingFeature', () async {
      List<String> failedScenarios = [];
      List<String> passedScenarios = [];
      for (final item in evalConditions) {
        final StickyBucketService service = InMemoryStickyBucketService();

        if (item is List<dynamic>) {
          final testData = GBFeaturesTest.fromMap(item[1]);
          final attributes =
              Map<String, dynamic>.from(testData.attributes ?? {});

          final gbContext = GBContext(
            apiKey: "",
            hostURL: "",
            enabled: true,
            attributes: attributes,
            forcedVariation: testData.forcedVariations ?? {},
            qaMode: false,
            trackingCallBack: (_) {},
            encryptionKey: "",
            stickyBucketService: service,
          );

          if (testData.features != null) {
            gbContext.features = testData.features!;
          }

          if (testData.forcedVariations != null) {
            gbContext.forcedVariation = testData.forcedVariations!;
          }

          final listActualStickyAssigmentsDoc = <StickyAssignmentsDocument>[];

          item[2].forEach((jsonElement) {
            listActualStickyAssigmentsDoc
                .add(StickyAssignmentsDocument.fromJson(jsonElement));
          });

          for (var doc in listActualStickyAssigmentsDoc) {
            await service.saveAssignments(doc);
          }
          await GBUtils.refreshStickyBuckets(gbContext, null, attributes, {});

          GBExperimentResultTest? expectedExperimentResult;
          if (item[4] == null) {
            expectedExperimentResult = null;
          } else {
            expectedExperimentResult = GBExperimentResultTest.fromMap(item[4]);
          }

          Map<String, StickyAssignmentsDocument> expectedStickyAssignmentDocs =
              <String, StickyAssignmentsDocument>{};

          (item[5] as Map<String, dynamic>).forEach((key, value) {
            expectedStickyAssignmentDocs[key] =
                StickyAssignmentsDocument.fromJson(value);
          });

          final evaluationContext =
              GBUtils.initializeEvalContext(gbContext, null);

          final evaluator = FeatureEvaluator();

          final actualExperimentResult = evaluator
              .evaluateFeature(evaluationContext, item[3])
              .experimentResult;

          String status =
              "\n${item[0]}\nExpected Result - ${item[4]} & $expectedStickyAssignmentDocs\n\nActual result - ${actualExperimentResult?.toJson()} & ${gbContext.stickyBucketAssignmentDocs}\n\n";

          if (expectedExperimentResult?.value.toString() ==
                  actualExperimentResult?.value.toString() &&
              _docsEqual(
                expectedStickyAssignmentDocs,
                evaluationContext.userContext.stickyBucketAssignmentDocs ?? {},
              )) {
            passedScenarios.add(status);
          } else {
            failedScenarios.add(status);
          }
        }
      }
      expect(failedScenarios.length, 0);
    });
  });
}
