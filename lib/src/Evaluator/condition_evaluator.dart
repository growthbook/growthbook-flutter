import 'package:flutter/foundation.dart';
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
  bool isEvalOr(Map<String, dynamic> attributes, List conditionObj, SavedGroupsValues savedGroups) {
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
  bool isEvalAnd(dynamic attributes, List conditionObj, SavedGroupsValues savedGroups) {
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
  bool isEvalConditionValue(dynamic conditionValue, dynamic attributeValue, SavedGroupsValues savedGroups) {
    // If conditionValue is a string, number, boolean, return true if it's
    // "equal" to attributeValue and false if not.
    if ((conditionValue as Object?).isPrimitive && (attributeValue as Object?).isPrimitive) {
      return conditionValue == attributeValue;
    }

    // Evaluate to false if attributeValue is null.
    if (conditionValue.isPrimitive && attributeValue == null) {
      return false;
    }

    // If conditionValue is array, return true if it's "equal" - "equal" should
    // do a deep comparison for arrays.
    if (conditionValue is List) {
      if (attributeValue is List) {
        if (conditionValue.length == attributeValue.length) {
          return listEquals(conditionValue, attributeValue);
        } else {
          return false;
        }
      } else {
        return false;
      }
    }

    // If conditionValue is an object, loop over each key/value pair:
    if (conditionValue is Map) {
      if (isOperatorObject(conditionValue)) {
        for (var key in conditionValue.keys) {
          // If evalOperatorCondition(key, attributeValue, value)
          // is false, return false
          if (!evalOperatorCondition(key, attributeValue, conditionValue[key], savedGroups)) {
            return false;
          }
        }
      } else if (attributeValue != null) {
        if (attributeValue is Map) {
          return mapEquals(conditionValue, attributeValue);
        } else {
          return attributeValue == conditionValue;
        }
      } else {
        return false;
      }
    }

    return true;
  }

  /// This checks if attributeValue is an array, and if so at least one of the
  /// array items must match the condition
  bool elemMatch(dynamic attributeValue, dynamic condition, SavedGroupsValues savedGroups) {
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
  bool evalOperatorCondition(
    String operator,
    dynamic attributeValue,
    dynamic conditionValue,
    SavedGroupsValues savedGroups,
  ) {
    /// Evaluate TYPE operator - whether both are of the same type
    if (operator == "\$type") {
      return getType(attributeValue).name == conditionValue;
    }

    /// Evaluate NOT operator - whether condition doesn't contain attribute
    if (operator == "\$not") {
      return !isEvalConditionValue(conditionValue, attributeValue, savedGroups);
    }

    /// Evaluate EXISTS operator - whether condition contains attribute
    if (operator == "\$exists") {
      if (conditionValue.toString() == 'false' && attributeValue == null) {
        return true;
      } else if (conditionValue.toString() == 'true' && attributeValue != null) {
        return true;
      }
    }

    switch (operator) {
      case "\$inGroup":
        return isIn(attributeValue, savedGroups[conditionValue] ?? []);
      case "\$notInGroup":
        return !isIn(attributeValue, savedGroups[conditionValue] ?? []);
    }

    /// There are three operators where conditionValue is an array
    if (conditionValue is List) {
      switch (operator) {
        case '\$in':
          return isIn(attributeValue, conditionValue);

        /// Evaluate NIN operator - attributeValue not in the conditionValue
        /// array.
        case '\$nin':
          return !isIn(attributeValue, conditionValue);

        /// Evaluate ALL operator - whether condition contains all attribute
        case '\$all':
          if (attributeValue is List) {
            /// Loop through conditionValue array
            /// If none of the elements in the attributeValue array pass
            /// evalConditionValue(conditionValue[i], attributeValue[j]),
            /// return false.
            for (var con in conditionValue) {
              var result = false;
              for (var attr in attributeValue) {
                if (isEvalConditionValue(con, attr, savedGroups)) {
                  result = true;
                }
              }
              if (!result) {
                return result;
              }
            }
            return true;
          } else {
            /// If attributeValue is not an array, return false
            return false;
          }
        default:
          return false;
      }
    } else if (attributeValue is List) {
      switch (operator) {
        /// Evaluate ELEMENT-MATCH operator - whether condition matches attribute
        case "\$elemMatch":
          return elemMatch(attributeValue, conditionValue, savedGroups);

        /// Evaluate SIE operator - whether condition size is same as that
        /// of attribute
        case "\$size":
          return isEvalConditionValue(conditionValue, attributeValue.length, savedGroups);

        default:
      }
    } else if ((attributeValue as Object?).isPrimitive && (conditionValue as Object?).isPrimitive) {
      final targetPrimitiveValue = double.tryParse(conditionValue.toString());
      final sourcePrimitiveValue = double.tryParse(attributeValue.toString());
      final paddedVersionTarget = GBUtils.paddedVersionString(conditionValue.toString());
      final paddedVersionSource = GBUtils.paddedVersionString(attributeValue?.toString() ?? '0.0');

      /// If condition is bool.
      bool evaluatedValue = false;
      switch (operator) {
        case "\$eq":
          evaluatedValue = conditionValue == attributeValue;
          break;
        case "\$ne":
          evaluatedValue = conditionValue != attributeValue;
          break;
        case "\$veq":
          return paddedVersionSource == paddedVersionTarget;
        case "\$vne":
          return paddedVersionSource != paddedVersionTarget;
        case "\$vgt":
          return paddedVersionSource > paddedVersionTarget;
        case "\$vgte":
          return paddedVersionSource >= paddedVersionTarget;
        case "\$vlt":
          return paddedVersionSource < paddedVersionTarget;
        case "\$vlte":
          return paddedVersionSource <= paddedVersionTarget;

        /// Evaluate LT operator - whether attribute less than to condition
        case '\$lt':
          if (conditionValue is String && attributeValue is String) {
            return attributeValue.compareTo(conditionValue) < 0;
          }
          evaluatedValue = (sourcePrimitiveValue ?? 0.0) < (targetPrimitiveValue ?? 0);
          break;

        /// Evaluate LTE operator - whether attribute less than or equal to condition
        case '\$lte':
          evaluatedValue = (sourcePrimitiveValue ?? 0.0) <= (targetPrimitiveValue ?? 0);
          break;

        /// Evaluate GT operator - whether attribute greater than to condition
        case '\$gt':
          if (conditionValue is String && attributeValue is String) {
            return attributeValue.compareTo(conditionValue) > 0;
          }
          evaluatedValue = (sourcePrimitiveValue ?? 0.0) > (targetPrimitiveValue ?? 0);
          break;

        case '\$gte':
          evaluatedValue = (sourcePrimitiveValue ?? 0.0) >= (targetPrimitiveValue ?? 0);
          break;

        case '\$regex':
          try {
            final regEx = RegExp(conditionValue.toString());
            evaluatedValue = regEx.hasMatch(attributeValue.toString());
          } catch (e) {
            evaluatedValue = false;
          }
          break;

        default:
          conditionValue = false;
      }
      return evaluatedValue;
    }
    return false;
  }

  bool isIn(dynamic actualValue, List<dynamic> conditionValue) {
    if (actualValue is List) {
      return actualValue.any((el) => conditionValue.contains(el));
    }
    return conditionValue.contains(actualValue);
  }
}
