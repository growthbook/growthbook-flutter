# 3.7.0+0
- Remote Evaluation

# 3.6.0+0
- onInitializationFailure callback

# 3.5.0+0
- generating padded version strings
- extension StringComparison for comparing strings lexicographically
- Sticky Bucket logic

# 3.4.0+0
- sse connection background sync

# 3.3.0+0
- cache manager and set refresh handler

# 3.2.0+0
- parentConditions property to GBExperiment and GBFeature

# 3.1.0+0

- v0.2.1: Incorporated Test Case for Null HashAttribute:
- Introduced a new test case to handle scenarios where an experiment's hashAttribute is null, ensuring comprehensive coverage of potential conditions
- Enforced a new test case to manage instances where an experiment's coverage is set to 0, ensuring robust handling of edge cases.
- Add featureId to ExperimentResult Object:
- ExperimentResult object by incorporating featureId, enriching the dataset for improved analysis and tracking capabilities.
- sse client
- added support streaming update
- prepareFeaturesData optimization
- attribute and hashVersion nullable at GBFilter
- v0.2.1: Add test case for when an experiment's hashAttribute is null
- v0.2.2: Add test case for when an experiment's hashAttribute is an integer
- v0.2.3: Implemented Test Case for Zero Coverage
- v0.2.3: Add test case for when an experiment's coverage is set to 0
- v0.4.0: New hashVersion, ranges, meta, filters, seed, name, and phase properties of Experiments:
- v0.4.1: hash function now returns null instead of -1 when an invalid hashVersion is specified
- v0.4.2: Add test cases when targeting condition value is null
- added decrypt function and set of test cases
- v0.5.0: Add support for new version string comparison operators ($veq, $vne, $vgt, $vgte, $vlt, $vlte) and new paddedVersionString helper function
- v0.5.0: New isIn helper function for conditions, plus new evalCondition test cases for $in and $nin operators when attribute is an array
- v0.5.1: Add 2 new test cases for matching on a $groups array attribute
- v0.5.2: Add 3 new test cases for comparison operators to handle more edge cases
- setEncryptedFeatures method
- Integrated CI/CD functionality, enhancing security and automation in the development pipeline

## 3.0.0+0
- Fixes [issue](https://github.com/alippo-com/GrowthBook-SDK-Flutter/issues/47)

## 2.1.0+0
- Fixes [issue](https://github.com/alippo-com/GrowthBook-SDK-Flutter/issues)

## 2.0.1+0
- Fixes [issue](https://github.com/alippo-com/GrowthBook-SDK-Flutter/issues/36) caused by analyzer.

## 2.0.0+0
- solves [#32](https://github.com/alippo-com/GrowthBook-SDK-Flutter/issues/32).

## 1.2.0+0
 - Breaking change: Made initialization of sdk asynchronous.
 - Added run method to Evaluate experiment. 
 - Removed SDKBuilder. 

## 1.1.2
- Fixed `feature` evaluation on string comparison.

## 1.1.1
- Fixed `condition` evaluation while attribute/s is/are null. 

## 1.1.0
- Migrated to dart 2.17.2.
- fix: Data parsing problem.
- Moved to json-serializable from manual one.
- Removed dependency: Enhanced Enum.
- fix: String comparison assessment.
- Added new test cases for string comparison.
- Changed `attr` type for `evaluateCondition`.

## 1.0.0+1
- First Release Version.
- AB Testing.
- Feature Flag.
- Percentage RollOut.