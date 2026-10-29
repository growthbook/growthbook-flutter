import 'package:growthbook_sdk_flutter/src/Utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growthbook_sdk_flutter/src/Utils/gb_filter.dart';
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

    test('Only non-empty strings and non-zero numbers are hash values', () {
      List<String> hashOf(dynamic id, {dynamic fallback}) =>
          GBUtils.getHashAttribute(
            attr: 'id',
            fallback: 'deviceId',
            attributes: {'id': id, 'deviceId': fallback},
          );

      for (final missing in <dynamic>[
        0,
        0.0,
        false,
        true,
        null,
        '',
        <dynamic>[],
        ['1'],
        <String, dynamic>{},
        {'a': '1'},
        double.nan,
        double.infinity,
      ]) {
        expect(hashOf(missing), ['id', ''], reason: '$missing');
        expect(hashOf(missing, fallback: 'd1'), ['deviceId', 'd1'],
            reason: '$missing with fallback');
        expect(hashOf(missing, fallback: missing), ['id', ''],
            reason: '$missing with the same fallback');
      }
      expect(hashOf(1.0), ['id', '1']);
      expect(hashOf(1), ['id', '1']);
      expect(hashOf(1.5), ['id', '1.5']);
      expect(hashOf(-2), ['id', '-2']);
      expect(hashOf('abc', fallback: 'd1'), ['id', 'abc']);
    });

    test('A filter on a missing hash value filters the user out', () {
      final filter = GBFilter(
        seed: 'seed',
        ranges: [
          [0.0, 1.0]
        ],
        attribute: 'id',
      );
      expect(GBUtils.isFilteredOut([filter], {'id': true}), isTrue);
      expect(GBUtils.isFilteredOut([filter], {'id': '1'}), isFalse);
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

    /// growthbook/growthbook#7401: one leading `v` and everything from the
    /// first `+` are stripped
    test('padded version string strips one leading v and build metadata', () {
      final plain = GBUtils.paddedVersionString('1.2.3');
      expect(GBUtils.paddedVersionString('v1.2.3'), plain);
      expect(GBUtils.paddedVersionString('vv1.2.3'), 'v1-    2-    3-~');
      expect(GBUtils.paddedVersionString('1.2.3+build'), plain);
      expect(GBUtils.paddedVersionString('v1.2.3+build+more.1-2'), plain);
      expect(GBUtils.paddedVersionString('1.2.3+'), plain);
      expect(GBUtils.paddedVersionString('+build'), '');
    });

    /// The regex kept "+build\nmore": `.` doesn't match a newline
    test(
        'padded version string cuts at the first + even when a newline follows',
        () {
      final plain = GBUtils.paddedVersionString('1.2.3');
      expect(GBUtils.paddedVersionString('1.2.3+build\nmore'), plain);
      expect(GBUtils.paddedVersionString('1.2.3+\n'), plain);
    });

    /// Quadratic for the regex: every `+` started a `.*` that failed at the
    /// newline (100 000 of them took seconds)
    test('padded version string runs in linear time on many + characters', () {
      final input = '${'+' * 100000}\n';
      final stopwatch = Stopwatch()..start();
      GBUtils.paddedVersionString(input);
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('TestDecrypt', () async {
      try {
        var testCases = GBTestHelper.getDecryptData();
        if (testCases == null) return;

        for (var jsonElement in testCases) {
          var test = jsonElement;
          if (test != null) {
            var payload = test[1] as String?;
            var key = test[2] as String?;
            if (payload == null || key == null) {
              continue;
            }
            var expectedElem = test[3];

            try {
              if (expectedElem is String) {
                final decrypted = await DecryptionUtils.decrypt(payload, key);
                final actual =
                    decrypted is String ? decrypted.trim() : decrypted;
                expect(actual, expectedElem);
              } else if (expectedElem == null) {
                expect(true, isTrue);
              }
            } on DecryptionException catch (error) {
              fail("message ${error.errorMessage}");
            } catch (error) {
              fail("An unexpected error occurred: $error");
            }
          }
        }
      } catch (error) {
        fail("An unexpected error occurred: $error");
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

    if (roundForCompare(source[0]) != roundForCompare(target[0]) ||
        roundForCompare(source[1]) != roundForCompare(target[1])) {
      return false;
    }
  }

  return true;
}

// Mirrors the JS SDK spec test: compare ranges at 8 decimals, floored.
double roundForCompare(double n) => (n * 1e8).floorToDouble() / 1e8;

List<GBBucketRange> getPairedData(List<List<double>> items) {
  List<GBBucketRange> pairExpectedResults = [];

  for (List<double> item in items) {
    double number1 = item[0];
    double number2 = item[1];
    pairExpectedResults.add([number1, number2]);
  }

  return pairExpectedResults;
}
