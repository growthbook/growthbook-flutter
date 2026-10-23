import 'dart:convert';
import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

/// Both experiments and features can define targeting conditions using a syntax modeled after MongoDB queries.
/// These conditions can have arbitrary nesting levels and evaluating them requires recursion.
/// There are a handful of functions to define, and be aware that some of them may reference function definitions further below.
/// Enum For different Attribute Types supported by GrowthBook.
enum GBAttributeType {
  /// String Type Attribute.
  gbString('string'),

  /// Number Type Attribute.
  gbNumber('number'),

  /// Boolean Type Attribute.
  gbBoolean('boolean'),

  //// Array Type Attribute.
  gbArray('array'),

  /// Object Type Attribute.
  gbObject('object'),

  /// Null Type Attribute.
  gbNull('null'),

  /// Not Supported Type Attribute.
  gbUnknown('unknown');

  const GBAttributeType(this.name);

  final String name;

  @override
  String toString() => name;
}

/// Evaluator class fro condition.
class GBConditionEvaluator {
  /// This is the main function used to evaluate a condition. It loops through the condition key/value pairs and checks each entry:
  /// - attributes : User Attributes
  /// - condition : to be evaluated
  bool isEvalCondition(
    Map<String, dynamic> attributes,
    dynamic conditionObj,
    // Must be included for `condition` to correctly evaluate group Operators
    SavedGroupsValues? savedGroups,
  ) {
    savedGroups ??= {};
    if (conditionObj is List) {
      return false;
    }
    if (conditionObj is Map<String, dynamic>) {
      for (var key in conditionObj.keys) {
        var value = conditionObj[key];
        switch (key) {
          case "\$or":
            if (!isEvalOr(attributes, value, savedGroups)) {
              return false;
            }
            break;
          case "\$nor":
            if (isEvalOr(attributes, value, savedGroups)) {
              return false;
            }
            break;
          case "\$and":
            if (!isEvalAnd(attributes, value, savedGroups)) {
              return false;
            }
            break;
          case "\$not":
            if (isEvalCondition(attributes, value, savedGroups)) {
              return false;
            }
            break;
          default:
            var element = getPath(attributes, key);
            if (!isEvalConditionValue(value, element, savedGroups)) {
              return false;
            }
        }
      }
    }
    // If none of the entries failed their checks, `evalCondition` returns true
    return true;
  }

  /// Evaluate OR conditions against given attributes
  bool isEvalOr(Map<String, dynamic> attributes, List conditionObj,
      SavedGroupsValues savedGroups) {
    // If conditionObj is empty, return true
    if (conditionObj.isEmpty) {
      return true;
    } else {
      // Loop through the conditionObjects
      for (var item in conditionObj) {
        // If evalCondition(attributes, conditionObj[i]) is true, break out of
        // the loop and return true
        if (isEvalCondition(attributes, item, savedGroups)) {
          return true;
        }
      }
    }
    // Return false
    return false;
  }

  /// Evaluate AND conditions against given attributes
  bool isEvalAnd(
      dynamic attributes, List conditionObj, SavedGroupsValues savedGroups) {
    // Loop through the conditionObjects

    // Loop through the conditionObjects
    for (var item in conditionObj) {
      // If evalCondition(attributes, conditionObj[i]) is true, break out of
      // the loop and return false
      if (!isEvalCondition(attributes, item, savedGroups)) {
        return false;
      }
    }
    // Return true
    return true;
  }

  /// This accepts a parsed JSON object as input and returns true if every key
  /// in the object starts with $
  bool isOperatorObject(dynamic obj) {
    if (obj is Map<String, dynamic> && obj.isNotEmpty) {
      return obj.keys.every((key) => key.startsWith('\$'));
    }
    return false;
  }

  ///  This returns the data type of the passed in argument.
  GBAttributeType getType(dynamic obj) {
    if (obj == null) {
      return GBAttributeType.gbNull;
    }

    final value = obj as Object;

    if (value.isPrimitive) {
      if (value.isString) {
        return GBAttributeType.gbString;
      } else if (value == true || value == false) {
        return GBAttributeType.gbBoolean;
      } else {
        return GBAttributeType.gbNumber;
      }
    }

    if (value.isArray) {
      return GBAttributeType.gbArray;
    }

    if (value.isMap) {
      return GBAttributeType.gbObject;
    }

    return GBAttributeType.gbUnknown;
  }

  /// Given attributes and a dot-separated path string, return the value at
  /// that path (or null/undefined if the path doesn't exist)
  dynamic getPath(dynamic obj, String key) {
    var paths = <String>[];

    if (key.contains(".")) {
      paths = key.split('.');
    } else {
      paths.add(key);
    }

    dynamic element = obj;
    for (final path in paths) {
      if (element == null || (element as Object).isArray) {
        return null;
      }
      if ((element is Map)) {
        element = element[path];
      } else {
        return null;
      }
    }

    return element;
  }

  ///Evaluates Condition Value against given condition & attributes
  bool isEvalConditionValue(
    dynamic conditionValue,
    dynamic attributeValue,
    SavedGroupsValues savedGroups, {
    bool inSensitive = false,
  }) {
    // Simple equality: the attribute must have the same type as the
    // condition, with no coercion ("10" does not equal 10).
    if (conditionValue is String ||
        conditionValue is num ||
        conditionValue is bool) {
      if (getType(attributeValue) != getType(conditionValue)) {
        return false;
      }
      if (inSensitive && conditionValue is String) {
        return (attributeValue as String).toLowerCase() ==
            conditionValue.toLowerCase();
      }
      return attributeValue == conditionValue;
    }

    if (conditionValue == null) {
      return attributeValue == null;
    }

    // Arrays and plain objects are compared deeply.
    if (conditionValue is List || !isOperatorObject(conditionValue)) {
      if (getType(attributeValue) != getType(conditionValue)) {
        return false;
      }
      try {
        return jsonEncode(attributeValue) == jsonEncode(conditionValue);
      } catch (_) {
        return false;
      }
    }

    // An operator object: every operator must pass.
    for (var key in (conditionValue as Map).keys) {
      if (!evalOperatorCondition(
          key, attributeValue, conditionValue[key], savedGroups)) {
        return false;
      }
    }
    return true;
  }

  /// This checks if attributeValue is an array, and if so at least one of the
  /// array items must match the condition
  bool elemMatch(dynamic attributeValue, dynamic condition,
      SavedGroupsValues savedGroups) {
    // Loop through items in attributeValue
    if (attributeValue is List) {
      for (final item in attributeValue) {
        // If isOperatorObject(condition)
        if (isOperatorObject(condition)) {
          // If evalConditionValue(condition, item), break out of loop and
          //return true
          if (isEvalConditionValue(condition, item, savedGroups)) {
            return true;
          }
        }
        // Else if evalCondition(item, condition), break out of loop and
        //return true
        else if (isEvalCondition(item, condition, savedGroups)) {
          return true;
        }
      }
    }
    // If attributeValue is not an array, return false
    return false;
  }

  /// This function is just a case statement that handles all the possible operators
  /// There are basic comparison operators in the form attributeValue {op}
  ///  conditionValue.
  ///
  /// When the attribute's type differs from the condition's, the positive
  /// operator fails and its negation matches.
  bool evalOperatorCondition(
    String operator,
    dynamic attributeValue,
    dynamic conditionValue,
    SavedGroupsValues savedGroups,
  ) {
    switch (operator) {
      case "\$veq":
      case "\$vne":
      case "\$vgt":
      case "\$vgte":
      case "\$vlt":
      case "\$vlte":
        return _evalVersion(operator, attributeValue, conditionValue);

      case "\$eq":
        return attributeValue == conditionValue;
      case "\$ne":
        return attributeValue != conditionValue;

      /// Only two numbers or two strings are ordered; strings compare as text.
      case '\$lt':
      case '\$lte':
      case '\$gt':
      case '\$gte':
        if (!_isOrderable(attributeValue, conditionValue)) return false;
        final comparison =
            (attributeValue as Comparable).compareTo(conditionValue);
        switch (operator) {
          case '\$lt':
            return comparison < 0;
          case '\$lte':
            return comparison <= 0;
          case '\$gt':
            return comparison > 0;
          default:
            return comparison >= 0;
        }

      /// Evaluate EXISTS operator - whether condition contains attribute
      case "\$exists":
        return _isTruthy(conditionValue)
            ? attributeValue != null
            : attributeValue == null;

      /// Evaluate TYPE operator - whether both are of the same type
      case "\$type":
        return getType(attributeValue).name == conditionValue;

      /// Evaluate NOT operator - whether condition doesn't contain attribute
      case "\$not":
        return !isEvalConditionValue(
            conditionValue, attributeValue, savedGroups);

      case "\$inGroup":
        return isIn(attributeValue, savedGroups[conditionValue] ?? []);
      case "\$notInGroup":
        return !isIn(attributeValue, savedGroups[conditionValue] ?? []);

      case '\$in':
        if (conditionValue is! List) return false;
        return isIn(attributeValue, conditionValue);

      /// Evaluate INI operator - case-insensitive version of $in
      case '\$ini':
        if (conditionValue is! List) return false;
        return isIn(attributeValue, conditionValue, inSensitive: true);

      /// Evaluate NIN operator - attributeValue not in the conditionValue
      /// array.
      case '\$nin':
        if (conditionValue is! List) return false;
        return !isIn(attributeValue, conditionValue);

      /// Evaluate NINI operator - case-insensitive version of $nin
      case '\$nini':
        if (conditionValue is! List) return false;
        return !isIn(attributeValue, conditionValue, inSensitive: true);

      /// Evaluate ALL operator - whether condition contains all attribute
      case '\$all':
        if (conditionValue is! List) return false;
        return _isInAll(attributeValue, conditionValue, savedGroups);

      /// Evaluate ALLI operator - case-insensitive version of $all
      case '\$alli':
        if (conditionValue is! List) return false;
        return _isInAll(attributeValue, conditionValue, savedGroups,
            inSensitive: true);

      /// Evaluate ELEMENT-MATCH operator - whether condition matches attribute
      case "\$elemMatch":
        return elemMatch(attributeValue, conditionValue, savedGroups);

      /// Evaluate SIZE operator - whether condition size is same as that
      /// of attribute
      case "\$size":
        if (attributeValue is! List) return false;
        return isEvalConditionValue(
            conditionValue, attributeValue.length, savedGroups);

      case '\$regex':
        return _evalRegex(
          conditionValue: conditionValue,
          attributeValue: attributeValue,
          isCaseSensitive: true,
          negate: false,
        );

      case '\$regexi':
        return _evalRegex(
          conditionValue: conditionValue,
          attributeValue: attributeValue,
          isCaseSensitive: false,
          negate: false,
        );

      case '\$notRegex':
        return _evalRegex(
          conditionValue: conditionValue,
          attributeValue: attributeValue,
          isCaseSensitive: true,
          negate: true,
        );

      case '\$notRegexi':
        return _evalRegex(
          conditionValue: conditionValue,
          attributeValue: attributeValue,
          isCaseSensitive: false,
          negate: true,
        );

      default:
        return false;
    }
  }

  /// Version operators need both sides to be strings, or both numbers.
  /// `$vne` is the opposite of `$veq`, so it matches on a type mismatch.
  bool _evalVersion(
      String operator, dynamic attributeValue, dynamic conditionValue) {
    if (!_isOrderable(attributeValue, conditionValue)) {
      return operator == "\$vne";
    }
    final source = GBUtils.paddedVersionString(_versionInput(attributeValue));
    final target = GBUtils.paddedVersionString(_versionInput(conditionValue));
    switch (operator) {
      case "\$veq":
        return source == target;
      case "\$vne":
        return source != target;
      case "\$vgt":
        return source > target;
      case "\$vgte":
        return source >= target;
      case "\$vlt":
        return source < target;
      default:
        return source <= target;
    }
  }

  /// Formats a number the way JavaScript does (`2.0` -> `"2"`).
  String _versionInput(dynamic value) {
    if (value is double && value.isFinite && value == value.truncate()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  bool _isOrderable(dynamic attributeValue, dynamic conditionValue) {
    return (attributeValue is num && conditionValue is num) ||
        (attributeValue is String && conditionValue is String);
  }

  bool _isTruthy(dynamic value) {
    return value != null &&
        value != false &&
        value != 0 &&
        value != '' &&
        !(value is double && value.isNaN);
  }

  bool isIn(dynamic actualValue, List<dynamic> conditionValue,
      {bool inSensitive = false}) {
    dynamic caseFold(dynamic value) {
      if (inSensitive && value is String) {
        return value.toLowerCase();
      }
      return value;
    }

    if (actualValue is List) {
      if (actualValue.isEmpty) return false;
      return actualValue.any(
        (attr) => conditionValue.any(
          (cond) => caseFold(attr) == caseFold(cond),
        ),
      );
    }
    return conditionValue.any(
      (cond) => caseFold(actualValue) == caseFold(cond),
    );
  }

  bool _isInAll(
    dynamic attributeValue,
    List<dynamic> conditionValue,
    SavedGroupsValues savedGroups, {
    bool inSensitive = false,
  }) {
    if (attributeValue is! List) return false;
    for (final condition in conditionValue) {
      var passed = false;
      for (final attribute in attributeValue) {
        if (isEvalConditionValue(condition, attribute, savedGroups,
            inSensitive: inSensitive)) {
          passed = true;
          break;
        }
      }
      if (!passed) return false;
    }
    return true;
  }

  bool _evalRegex({
    required dynamic conditionValue,
    required dynamic attributeValue,
    required bool isCaseSensitive,
    required bool negate,
  }) {
    if (attributeValue is! String) return negate;
    if (conditionValue == null) return false;
    try {
      final regex =
          RegExp(conditionValue.toString(), caseSensitive: isCaseSensitive);
      final matches = regex.hasMatch(attributeValue);
      return negate != matches;
    } catch (_) {
      return false;
    }
  }
}
