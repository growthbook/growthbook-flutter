import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';
import 'package:growthbook_sdk_flutter/src/Utils/utils.dart';

import '../Helper/gb_test_helper.dart';

void main() {
  group('GBUtils', () {
    test('test hash', () async {
      final evalConditions = GBTestHelper.getFNVHashData();
      List<String> failedScenarios = [];
      List<String> passedScenarios = [];

      for (var item in evalConditions) {
        final seed = item[0];
        final testContext = item[1];
        final hashVersion = item[2];
        final experiment = item[3];

        final result =
            GBUtils.hash(seed: seed, value: testContext, version: hashVersion);

        final status =
            '${item[0]} \nExpected Result: ${item[1]} \nActual Result: $result\n';

        if (experiment == result) {
          passedScenarios.add(status);
        } else {
          failedScenarios.add(status);
        }
      }

      expect(failedScenarios.isEmpty, isTrue);
    });

    test('test bucket range', () async {
      final evalConditions = GBTestHelper.getBucketRangeData();
      List<String> failedScenarios = [];
      List<String> passedScenarios = [];

      for (var item in evalConditions) {
        final numVariations = item[1][0];
        final coverage = double.parse(item[1][1].toString());
        List<double>? weights;
        if (item[1][2] != null) {
          weights = item[1][2]
              .map<double>((value) => double.parse(value.toString()))
              .toList();
        }

        final bucketRange = GBUtils.getBucketRanges(
            numVariations ?? 1, coverage, weights ?? []);

        final status =
            '${item[0]} \nExpected Result: $item \nActual Result: $bucketRange\n';

        List<List<double>> comparer = [];
        for (var element in (item[2] as List)) {
          final subList = <double>[];
          for (var element in (element as List)) {
            subList.add(double.parse(element.toString()));
          }
          comparer.add(subList);
        }
        if (isCompareBucket(comparer, bucketRange)) {
          passedScenarios.add(status);
        } else {
          failedScenarios.add(status);
        }
      }

      expect(failedScenarios.isEmpty, isTrue);
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
      logger.i(
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
        final status =
            "${item[0]}\nExpected Result - ${item[3]}\nActual result - $result\n";
        if (item[3].toString() == result.toString()) {
          passedScenarios.add(status);
        } else {
          failedScenarios.add(status);
        }
      }
      logger.i(
          'Passed Test ${passedScenarios.length} out of ${evaluateConditions.length}');
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
          final status =
              "Expected Result - ${item[1]}\nActual result - $result\n";

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

      logger.i(
          'Passed Test ${passedScenarios.length} out of ${evalCondition.length}');
      expect(failedScenarios.length, 0);
    });

    test('test edge cases', () async {
      expect(GBUtils.inNamespace('4242', const GBNameSpace('', 0.0, 0.0)),
          isFalse);

      List<dynamic> items = [1];
      expect(GBUtils.getGBNameSpace(items), isNull);
    });

    test('test padded version string', () async {
      const startValue = 'v1.2.3-rc.1+build123';
      const expectedValue = '    1-    2-    3-rc-    1';
      final endValue = GBUtils.paddedVersionString(startValue);

      expect(endValue, expectedValue);
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
            logger.i("message ${error.errorMessage}");

            if (expectedElem == null) {
              expect(true, isTrue);
            }
          } catch (error) {
            fail("An unexpected error occurred: $error");
          }
        }
      } catch (error) {
        logger.i("An unexpected error occurred: $error");
      }
    });
  });
}

List<List<double>> convertToDoubleLists(List<dynamic> dynamicList) {
  return dynamicList.map((dynamic innerList) {
    return (innerList as List<double>).map((double value) {
      return value.toDouble();
    }).toList();
  }).toList();
}

bool compareBucket(
    List<List<double>> expectedResult, List<GBBucketRange> calculatedResult) {
  var pairedExpectedResult = getPairedData(expectedResult);
  if (pairedExpectedResult.length != expectedResult.length) {
    return false;
  }
  var result = true;
  for (var i = 0; i < pairedExpectedResult.length; i++) {
    var source = pairedExpectedResult[i];
    var target = calculatedResult[i];

    if (source[0] != target[0] || source[1] != target[1]) {
      result = false;
      break;
    }
  }
  return result;
}

bool isCompareBucket(
    List<List<double>> expectedResults, List<GBBucketRange> calculatedResults) {
  List<GBBucketRange> pairExpectedResults = getPairedData(expectedResults);

  if (pairExpectedResults.length != expectedResults.length) {
    return false;
  }

  for (int i = 0; i < pairExpectedResults.length; i++) {
    GBBucketRange source = pairExpectedResults[i];
    GBBucketRange target = calculatedResults[i];

    if (source[0] != target[0] || source[1] != target[1]) {
      return false;
    }
  }

  return true;
}

List<GBBucketRange> getPairedData(List<List<double>> items) {
  List<GBBucketRange> pairExpectedResults = [];

  for (List<double> item in items) {
    double number1 = item[0];
    double number2 = item[1];
    pairExpectedResults.add([number1, number2]);
  }

  return pairExpectedResults;
}
