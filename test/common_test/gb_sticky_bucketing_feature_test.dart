import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/Model/sticky_assignments_document.dart';

import '../Helper/gb_test_helper.dart';

void main() {
  group('GBStickyBucketingFeatureTests', () {
    late List<dynamic> evalConditions;
    late GBStickyBucketingService service;

    setUp(() {
      evalConditions = GBTestHelper.getStickyBucketingData();
      service = GBStickyBucketingService();
    });

    test('testEvaluateFeatureWithStickyBucketingFeature', () {
      List<String> failedScenarios = [];
      List<String> passedScenarios = [];
      for (final item in evalConditions) {
        if (item is List<dynamic>) {
          final testData = GBFeaturesTest.fromMap(item[1]);
          final attributes = Map<String, dynamic>.from(testData.attributes ?? {});

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
            listActualStickyAssigmentsDoc.add(StickyAssignmentsDocument.fromJson(jsonElement));
          });

          final mapOfDocForContext = <String, StickyAssignmentsDocument>{};

          for (var doc in listActualStickyAssigmentsDoc) {
            final key = "${doc.attributeName}||${doc.attributeValue}";
            mapOfDocForContext[key] = doc;
          }

          gbContext.stickyBucketAssignmentDocs = mapOfDocForContext;

          GBExperimentResultTest? expectedExperimentResult;
          if (item[4] == null) {
            expectedExperimentResult = null;
          } else {
            expectedExperimentResult = GBExperimentResultTest.fromMap(item[4]);
          }

          Map<String, StickyAssignmentsDocument> expectedStickyAssignmentDocs = <String, StickyAssignmentsDocument>{};

          (item[5] as Map<String, dynamic>).forEach((key, value) {
            expectedStickyAssignmentDocs[key] = StickyAssignmentsDocument.fromJson(value);
          });

          final evaluationContext = GBUtils.initializeEvalContext(gbContext, null);

          final evaluator =
              FeatureEvaluator(attributeOverrides: attributes, context: evaluationContext, featureKey: item[3]);

          final actualExperimentResult = evaluator.evaluateFeature().experimentResult;

          String status =
              "\n${item[0]}\nExpected Result - ${item[4]} & $expectedStickyAssignmentDocs\n\nActual result - ${actualExperimentResult?.toJson()} & ${gbContext.stickyBucketAssignmentDocs}\n\n";

          if (expectedExperimentResult?.value.toString() == actualExperimentResult?.value.toString() &&
              expectedStickyAssignmentDocs.toString() == gbContext.stickyBucketAssignmentDocs.toString()) {
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
