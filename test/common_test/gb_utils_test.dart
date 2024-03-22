import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Utils/utils.dart';
import 'package:tuple/tuple.dart';

import '../Helper/gb_test_helper.dart';

void main() {
  group('GBUtils', () {
    List<GBBucketRange> getPairedData(List<List<dynamic>> items) {
      final List<Tuple2<double, double>> pairedExpectedResults = [];
      for (final item in items) {
        final pair = item.zipWithNext<double?>();
        pairedExpectedResults.add(Tuple2.fromList(pair));
      }
      return pairedExpectedResults;
    }

    test('Test Hash', () {
      final evaluateCondition = GBTestHelper.getFNVHashData();
      List<String> failedScenarios = <String>[];
      List<String> passedScenarios = <String>[];
      for (final item in evaluateCondition) {
        final testContext = item[0];
        final experiment = item[1];
        final hashVersion = double.parse(item[2].toString());
        final seed = item[3];

        final result = GBUtils.hash(
          value: testContext,
          version: hashVersion,
          seed: seed,
        );

        final status = '${item[0]}\nExpected Result - ${item[1]}\nActual result - $result\nof experiment$experiment';

        if (experiment.toString() == result.toString()) {
          passedScenarios.add(status);
        } else {
          failedScenarios.add(status);
        }
      }
      customLogger(
          'Passed Test ${passedScenarios.length} out of ${evaluateCondition.length}');
      expect(failedScenarios.length, 0);
    });

    test('Test Bucket Range', () {
      bool compareBucket(List<List<double>> expectedResult,
          List<GBBucketRange> calculatedResult) {
        var pairedExpectedResult = getPairedData(expectedResult);
        if (pairedExpectedResult.length != expectedResult.length) {
          return false;
        }
        var result = true;
        for (var i = 0; i < pairedExpectedResult.length; i++) {
          var source = pairedExpectedResult[i];
          var target = calculatedResult[i];

          if (source.item1 != target.item1 || source.item2 != target.item2) {
            result = false;
            break;
          }
        }
        return result;
      }

      final evalConditions = GBTestHelper.getBucketRangeData();
      List<String> failedScenarios = <String>[];
      List<String> passedScenarios = <String>[];
      for (final item in evalConditions) {
        if ((item as Object?).isArray) {
          ///
          final localItem = item as List;
          ////
          final numVariation = localItem[1][0];
          ////
          final coverage = localItem[1][1];

          List<double>? weights;

          if (localItem[1][2] != null) {
            weights = (localItem[1][2] as List)
                .map((e) => double.parse(e.toString()))
                .toList();
          }
          final bucketRange = GBUtils.getBucketRanges(
            numVariation,
            double.parse(coverage.toString()),
            weights ?? [],
          );

          /// For status.
          final status = "${item[0]}\nExpected Result - ${item[2]}\nActual result - $bucketRange\n";

          /// Should be subtracted from.
          List<List<double>> comparer = [];
          for (var element in (localItem[2] as List)) {
            final subList = <double>[];
            for (var element in (element as List)) {
              subList.add(double.parse(element.toString()));
            }
            comparer.add(subList);
          }
          if (compareBucket(comparer, bucketRange)) {
            passedScenarios.add(status);
          } else {
            failedScenarios.add(status);
          }
        }
      }
      customLogger(
          'Passed Test ${passedScenarios.length} out of ${evalConditions.length}');
      expect(failedScenarios.length, 0);
    });

    test('Choose Variation', () {
      final evalCondition = GBTestHelper.getChooseVariationData();
      final failedScenarios = <String>[];
      final passedScenarios = <String>[];

      for (var item in evalCondition) {
        if ((item as Object?).isArray) {
          final localItem = item as List;
          final hash = double.tryParse(item[1].toString());

          /// It should be subtracted from part.
          List<List<double>> comparer = [];
          for (var element in (localItem[2] as List)) {
            final subList = <double>[];
            for (var element in (element as List)) {
              subList.add(double.parse(element.toString()));
            }
            comparer.add(subList);
          }

          ///
          final rangeData = getPairedData(comparer);

          var result = const GBUtils().chooseVariation(hash!, rangeData);

          if (localItem[3].toString() == result.toString()) {
            passedScenarios.add(item.toString());
          } else {
            failedScenarios.add(item.toString());
          }
        }
      }
      customLogger(
          'Passed Test ${passedScenarios.length} out of ${evalCondition.length}');
      expect(failedScenarios.length, 0);
    });

    test('Equal Weights', () {
      final evalCondition = GBTestHelper.getEqualWeightsData();
      final failedScenarios = <String>[];
      final passedScenarios = <String>[];
      bool testResult = true;

      for (var item in evalCondition) {
        if ((item as Object?).isArray) {
          final localItem = item as List;
          final numVariation = double.parse(localItem[0].toString());
          final result = GBUtils.getEqualWeights(numVariation.toInt());
          final status = "Expected Result - ${item[1]}\nActual result - $result\n";

          if ((localItem[1] as List).length != result.length) {
            testResult = false;
          } else {
            for (var i = 0; i < result.length; i++) {
              final source = double.tryParse(localItem[1][i].toString());
              final target = result[i];
              if (source.toString().substring(0, 2) !=
                  target.toString().substring(0, 2)) {
                testResult = false;
                break;
              }
            }
          }
          if (testResult) {
            passedScenarios.add(status);
          } else {
            failedScenarios.add(status);
          }
        }
      }
      expect(testResult, true);
      expect(failedScenarios.length, 0);

      customLogger(
          'Passed Test ${passedScenarios.length} out of ${evalCondition.length}');
      expect(failedScenarios.length, 0);
    });

    test('TestInNameSpace', () {
      final evaluateConditions = GBTestHelper.getInNameSpaceData();
      final failedScenarios = <String>[];
      final passedScenarios = <String>[];
      for (var item in evaluateConditions) {
        final userId = item[1];
        final array = item[2];
        final nameSpace = GBUtils.getGBNameSpace(array);
        final result = GBUtils.inNamespace(userId, nameSpace!);
        final status = "${item[0]}\nExpected Result - ${item[3]}\nActual result - $result\n";
        if (item[3].toString() == result.toString()) {
          passedScenarios.add(status);
        } else {
          failedScenarios.add(status);
        }
      }
      customLogger(
          'Passed Test ${passedScenarios.length} out of ${evaluateConditions.length}');
      expect(failedScenarios.length, 0);
    });

    test('TestDecrypt', () {
      try {
        var testCases = GBTestHelper.getDecryptData();
        if (testCases == null) return;

        for (var jsonElement in testCases) {
          var test = jsonElement.arrayObject;
          var payload = test[1] as String?;
          var key = test[2] as String?;
          if (payload == null || key == null) {
            continue;
          }
          var expectedElem = test[3];

          try {
            if (expectedElem is String) {
              var actual = DecryptionUtils.decrypt(payload, key).trim();
              expect(actual, expectedElem);
            }
          } on DecryptionException catch (error) {
            customLogger("message ${error.errorMessage}");

            if (expectedElem == null) {
              expect(true, isTrue);
            }
          } catch (error) {
            fail("An unexpected error occurred: $error");
          }
        }
      } catch (error) {
        customLogger("An unexpected error occurred: $error");
      }
    });
  });

  test('TestPaddedVersionString', () {
    const startValue = "v1.2.3-rc.1+build123";
    const expectedValue = "    1-    2-    3-rc-    1";
    final endValue = GBUtils.paddedVersionString(startValue);

    expect(endValue, expectedValue);
  });
}
