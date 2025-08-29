# 4.0.1
* updated README and corrected CHANGELOG 

## [4.0.0](https://github.com/growthbook/growthbook-flutter/compare/v3.9.14...v4.0.0) (2025-07-30)


### ⚠ BREAKING CHANGES

* include .g.dart files in published packages

### Bug Fixes

* add setup, build_runner to publish workflow ([963503c](https://github.com/growthbook/growthbook-flutter/commit/963503c4a93c7f5d752a469891f67ba950c84fcf))
* analyzer issues ([226ee7f](https://github.com/growthbook/growthbook-flutter/commit/226ee7f55b9fde8a8a24927e7f3b944197a96710))
* detached HEAD ([f8264d9](https://github.com/growthbook/growthbook-flutter/commit/f8264d97ef771d15777f94beb8828484b820e9ff))
* include .g.dart files in published packages ([f2f64fe](https://github.com/growthbook/growthbook-flutter/commit/f2f64fea1c22c427639bb94580c5f72702a1ace3))
* include .g.dart files in published packages ([f2f64fe](https://github.com/growthbook/growthbook-flutter/commit/f2f64fea1c22c427639bb94580c5f72702a1ace3))
* include .g.dart files in published packages ([ef12356](https://github.com/growthbook/growthbook-flutter/commit/ef12356baf41a8da3f9f59abafe02ca4ea67ca7c))
* update dart SDK constraint to &gt;=3.3.0 ([00973d7](https://github.com/growthbook/growthbook-flutter/commit/00973d7d473a1a675e2adc4362ff3b6e71b3ea59))
* update Flutter version to 3.24.0 ([c34afb5](https://github.com/growthbook/growthbook-flutter/commit/c34afb5698b3c651ff84b32a4426393a4e60f8bf))
* update Flutter version to 3.27.0 and upgrade build_runner to ^2.4.14 ([cfcc146](https://github.com/growthbook/growthbook-flutter/commit/cfcc146d616359a0bcb67ec393d9b188c8ffdbed))

## [3.9.14](https://github.com/growthbook/growthbook-flutter/compare/v3.9.13...v3.9.14) (2025-07-24)


### Bug Fixes

* bug fixes for eval & sticky bucketing ([d85d4dd](https://github.com/growthbook/growthbook-flutter/commit/d85d4dd4f629510a5ae89c396753dd967fa924d3))
* release template  ([33af84a](https://github.com/growthbook/growthbook-flutter/commit/33af84a6f35a98a9fb85a96ce10b9c2e085b8147))

## [3.9.13](https://github.com/growthbook/growthbook-flutter/compare/v3.9.12...v3.9.13) (2025-07-24)


### Bug Fixes

* bug fixes ([b0fe046](https://github.com/growthbook/growthbook-flutter/commit/b0fe046aa6ccb9eebc84988335839c28c02c2ef8))
* bug fixes for eval & sticky bucketing ([d85d4dd](https://github.com/growthbook/growthbook-flutter/commit/d85d4dd4f629510a5ae89c396753dd967fa924d3))
* release template  ([33af84a](https://github.com/growthbook/growthbook-flutter/commit/33af84a6f35a98a9fb85a96ce10b9c2e085b8147))

# 3.9.12
-   update version of Growthbook Flutter SDK
 -  All methods now use a single _evaluationContext that includes sticky bucket data.
 -  refresh() now also synchronizes this context.
 -  Sticky bucketing now works correctly at all times.
 
 # 3.9.11
- Added ability to set custom path for caching 
- Added ability to provide a custom implementation of cache storage
- Added support for setting a cache key for stored entries
- Removed singleton pattern from `CachingManager`
- Fixed subscription logic
- Added getAllResults method
- Updated subscribe method

## [3.9.11](https://github.com/growthbook/growthbook-flutter/compare/v3.9.10...v3.9.11) (2025-06-19)

### Bug Fixes

* type conversions ([4324001](https://github.com/growthbook/growthbook-flutter/commit/4324001ad1d1cbf3839eec05cc50ae9d33f3bf88))

# 3.9.10
- Moved TrackData to constant.dart to ensure it is publicly accessible and can be imported correctly without relying on internal paths.
- Updated project functionality to align with version 0.7.1 change log:
- Added feature rule ID to the FeatureResult object and updated all related test cases.
- Added new tests for pre-requisite edge cases.
- Ensured only known properties are copied from feature rules to experiments.
- Expanded evalCondition tests to cover null/false edge cases.
- Added test cases for URL redirects.

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
