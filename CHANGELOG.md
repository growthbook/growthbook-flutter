# 3.9.10
-   Moved TrackData to constant.dart to ensure it is publicly accessible and can be imported correctly without relying on internal paths.
- - Updated project functionality to align with version 0.7.1 change log:
- - Added feature rule ID to the FeatureResult object and updated all related test cases.
- - Added new tests for pre-requisite edge cases.
- - Ensured only known properties are copied from feature rules to experiments.
- - Expanded evalCondition tests to cover null/false edge cases.
- - Added test cases for URL redirects.

# 3.9.9
- Enable Multi Context Support

# 3.9.8
- Fix SSE connection
- Fix building feature url
- Create separate method autorefresh for SSE functionality

# 3.9.7
- Update hash function to get same result on web & mobile.

# 3.9.6
- Fixed issue with fallback attribute ignoring when needed.

# 3.9.5
- Add subscription logic
- Fix issue with null handling
- Fix hashing on web
- Update cache saving logic

# 3.9.4
- New Operators $inGroup and $notInGroup to check Saved Groups by reference
- Add argument to evalCondition for definition of Saved Groups
- Add test cases for evalCondition, feature, and run using the new operators

# 3.9.3
- Support Caching Manager on Flutter Web
- Remove a broken test case
- Add equatable for StickyAssignmentsDocument
- Add different type of exception handling for get features request

# 3.9.2
- Allowing multiple keys on a single level, even with operators like $or
- Add feature usage callback
- isOn and evalFeature methods to GrowthBookSDK
- Add tracking callback and feature usage callback tests
  
# 3.9.1
- v0.6.0: Tweak to isIncludedInRollout to handle an edge case when coverage is zero. Also added test case for this
- v0.6.0: Remove versionCompare test cases (these are now just included as part of evalCondition)
- v0.6.0: Add id property to feature rules (reserved for future use)
- Add common tests and make fixes

# 3.9.0
- Expose dio client to enable overrideable
- Export as independent method listenAndRetry
- To runnable on Web, use Utf8Encoder or Utf8Decoder instead of utf8.encode or utf8.decode
- Export experiment result

# 3.8.0+0
- add StickyBucketing test cases

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
