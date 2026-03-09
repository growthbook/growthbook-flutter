import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/StickyBucketService/sticky_bucket_service.dart';

import '../Helper/gb_test_helper.dart';

void main() {
  runStickyBucketingTests(
    name: 'FileStickyBucketService',
    serviceFactory: () => GBFileStickyBucketingService(),
  );

  runStickyBucketingTests(
    name: 'InMemoryStickyBucketService',
    serviceFactory: () => GBInMemoryStickyBucketingService(),
  );
}

void runStickyBucketingTests({
  required String name,
  required StickyBucketService Function() serviceFactory,
}) {
  group('GBStickyBucketingFeatureTests [$name]', () {
    late List<dynamic> evalConditions;
    late StickyBucketService service;

    setUp(() {
      evalConditions = GBTestHelper.getStickyBucketingData();
      service = serviceFactory();
    });

    test('testEvaluateFeatureWithStickyBucketingFeature', () {
      final failedScenarios = <String>[];
      final passedScenarios = <String>[];

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

          final mapOfDocForContext = {
            for (var doc in listActualStickyAssigmentsDoc) "${doc.attributeName}||${doc.attributeValue}": doc
          };

          gbContext.stickyBucketAssignmentDocs = mapOfDocForContext;

          final expectedExperimentResult = item[4] == null ? null : GBExperimentResultTest.fromMap(item[4]);

          final expectedStickyAssignmentDocs = <String, StickyAssignmentsDocument>{};
          (item[5] as Map<String, dynamic>).forEach((key, value) {
            expectedStickyAssignmentDocs[key] = StickyAssignmentsDocument.fromJson(value);
          });

          final evaluationContext = GBUtils.initializeEvalContext(gbContext, null);
          final evaluator = FeatureEvaluator();

          final actualExperimentResult = evaluator.evaluateFeature(evaluationContext, item[3]).experimentResult;

          final actualStickyDocs = evaluationContext.userContext.stickyBucketAssignmentDocs;

          final status = "\n${item[0]}\n"
              "Expected Result - ${item[4]} & $expectedStickyAssignmentDocs\n"
              "Actual Result   - ${actualExperimentResult?.toJson()} & $actualStickyDocs\n";

          final passed = expectedExperimentResult?.value.toString() == actualExperimentResult?.value.toString() &&
              expectedStickyAssignmentDocs.toString() == actualStickyDocs.toString();

          if (passed) {
            passedScenarios.add(status);
          } else {
            failedScenarios.add(status);
          }
        }
      }

      expect(failedScenarios.length, 0, reason: failedScenarios.join('\n'));
    });
  });
}
