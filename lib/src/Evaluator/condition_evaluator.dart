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
  /// A JavaScript decimal numeric string: an optional sign, then `Infinity` or
  /// digits with an optional fraction and exponent (`5`, `.5`, `5.`, `1e3`).
  static final _jsDecimalLiteral =
      RegExp(r'^[+-]?(Infinity|(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)$');

  /// This is the main function used to evaluate a condition. It loops through the condition key/value pairs and checks each entry:
  /// - attributes : User Attributes
  /// - condition : to be evaluated
  /// - visited : ids of the saved groups currently being resolved through
  ///   `$savedGroup`, so a group that references itself — directly or along a
  ///   chain — stops instead of recursing forever. Callers outside the evaluator
  ///   leave it at the default.
  bool isEvalCondition(
    Map<String, dynamic> attributes,
    dynamic conditionObj,
    // Must be included for `condition` to correctly evaluate group Operators
    SavedGroupsValues? savedGroups, {
    Set<String> visited = const <String>{},
  }) {
    savedGroups ??= {};
    if (conditionObj is List) {
      return false;
    }
    if (conditionObj is Map<String, dynamic>) {
      for (var key in conditionObj.keys) {
        var value = conditionObj[key];
        switch (key) {
          case "\$or":
            if (!isEvalOr(attributes, value, savedGroups, visited: visited)) {
              return false;
            }
            break;
          case "\$nor":
            if (isEvalOr(attributes, value, savedGroups, visited: visited)) {
              return false;
            }
            break;
          case "\$and":
            if (!isEvalAnd(attributes, value, savedGroups, visited: visited)) {
              return false;
            }
            break;
          case "\$not":
            if (isEvalCondition(attributes, value, savedGroups,
                visited: visited)) {
              return false;
            }
            break;
          // A top-level operator like `$and` / `$or`: it names a saved group
          // rather than an attribute, and the group decides what to test
          case "\$savedGroup":
            if (!_evalSavedGroup(attributes, value, savedGroups, visited)) {
              return false;
            }
            break;
          default:
            var element = getPath(attributes, key);
            if (!isEvalConditionValue(value, element, savedGroups,
                visited: visited)) {
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
      SavedGroupsValues savedGroups,
      {Set<String> visited = const <String>{}}) {
    // If conditionObj is empty, return true
    if (conditionObj.isEmpty) {
      return true;
    } else {
      // Loop through the conditionObjects
      for (var item in conditionObj) {
        // If evalCondition(attributes, conditionObj[i]) is true, break out of
        // the loop and return true
        if (isEvalCondition(attributes, item, savedGroups, visited: visited)) {
          return true;
        }
      }
    }
    // Return false
    return false;
  }

  /// Evaluate AND conditions against given attributes
  bool isEvalAnd(
      dynamic attributes, List conditionObj, SavedGroupsValues savedGroups,
      {Set<String> visited = const <String>{}}) {
    // Loop through the conditionObjects

    // Loop through the conditionObjects
    for (var item in conditionObj) {
      // If evalCondition(attributes, conditionObj[i]) is true, break out of
      // the loop and return false
      if (!isEvalCondition(attributes, item, savedGroups, visited: visited)) {
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
    Set<String> visited = const <String>{},
  }) {
    // A primitive condition converts the attribute to the condition's type
    // before comparing, as the reference SDK does (`mongrule.ts`):
    // `value + "" === condition` for a string, `value * 1 === condition` for a
    // number, `!!value === condition` for a boolean. So `{"age": 25}` matches
    // "25", and `{"beta": true}` matches 1.
    if (conditionValue is String) {
      final text = _jsText(attributeValue);
      return inSensitive
          ? text.toLowerCase() == conditionValue.toLowerCase()
          : text == conditionValue;
    }
    if (conditionValue is num) {
      // Two numbers keep Dart's exact comparison, so ids past 2^53 are not
      // rounded into each other
      if (attributeValue is num) return attributeValue == conditionValue;
      return _jsNumber(attributeValue) == conditionValue.toDouble();
    }
    if (conditionValue is bool) {
      return attributeValue != null &&
          _isJsTruthy(attributeValue) == conditionValue;
    }
    if (conditionValue == null) {
      return attributeValue == null;
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
          if (!evalOperatorCondition(
              key, attributeValue, conditionValue[key], savedGroups,
              visited: visited)) {
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
  bool elemMatch(
      dynamic attributeValue, dynamic condition, SavedGroupsValues savedGroups,
      {Set<String> visited = const <String>{}}) {
    // Loop through items in attributeValue
    if (attributeValue is List) {
      for (final item in attributeValue) {
        // Skip null elements only, like the reference SDK: otherwise an array
        // that merely contains a null satisfies any negation-flavoured body
        // (`$ne`, `$nin`, `$exists: false`). Falsy-but-present members (0,
        // false, "") are valid values and must still be tested.
        if (item == null) continue;
        // If isOperatorObject(condition)
        if (isOperatorObject(condition)) {
          // If evalConditionValue(condition, item), break out of loop and
          //return true
          if (isEvalConditionValue(condition, item, savedGroups,
              visited: visited)) {
            return true;
          }
        }
        // Else if evalCondition(item, condition), break out of loop and
        //return true. A non-object element has no paths, so every key
        // resolves to null, as in the reference SDK; passing it through as is
        // would throw on the Map parameter type.
        else if (isEvalCondition(
            item is Map<String, dynamic> ? item : const <String, dynamic>{},
            condition,
            savedGroups,
            visited: visited)) {
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
  /// Operators that accept an operand of any shape are dispatched on the
  /// operator alone, before the branches below that narrow on the operand type.
  /// Placing one of them inside such a branch makes it silently answer false —
  /// for both polarities — whenever the attribute has another shape.
  bool evalOperatorCondition(String operator, dynamic attributeValue,
      dynamic conditionValue, SavedGroupsValues savedGroups,
      {Set<String> visited = const <String>{}}) {
    /// Evaluate TYPE operator - whether both are of the same type
    if (operator == "\$type") {
      return getType(attributeValue).name == conditionValue;
    }

    /// Evaluate NOT operator - whether condition doesn't contain attribute
    if (operator == "\$not") {
      return !isEvalConditionValue(conditionValue, attributeValue, savedGroups,
          visited: visited);
    }

    /// Evaluate EXISTS operator - whether condition contains attribute. The
    /// reference SDK reads the condition value in a boolean context
    /// (`expected ? actual != null : actual == null`), so it follows JavaScript
    /// truthiness rather than requiring a JSON boolean: `$exists: 1` asks for a
    /// present attribute, `$exists: 0` for an absent one. Comparing the value's
    /// text with "true" / "false" let any other value match in neither direction.
    if (operator == "\$exists") {
      final present = attributeValue != null;
      return _isJsTruthy(conditionValue) ? present : !present;
    }

    /// Evaluate INGROUP / NOTINGROUP operators - whether the attribute is a
    /// member of a saved group. `isIn` covers an array attribute (intersection),
    /// a primitive one and an absent one.
    if (operator == "\$inGroup" || operator == "\$notInGroup") {
      // An entry these operators cannot read fails *both* of them closed.
      // Substituting an empty list would let `$notInGroup` pass everyone
      // through an exclusion rule.
      final group = _savedGroupListValues(savedGroups, conditionValue);
      if (group == null) return false;
      final isMember = isIn(attributeValue, group);
      return operator == "\$inGroup" ? isMember : !isMember;
    }

    /// Evaluate the regex family - dispatched on the operator alone, like the
    /// reference SDK, so array and object attributes are matched against their
    /// text instead of falling through to false both ways.
    switch (operator) {
      case "\$regex":
      case "\$regexi":
      case "\$notRegex":
      case "\$notRegexi":
        return _evalRegex(
          pattern: conditionValue,
          attributeValue: _regexInput(attributeValue),
          isCaseSensitive: operator == "\$regex" || operator == "\$notRegex",
          negate: operator == "\$notRegex" || operator == "\$notRegexi",
        );
    }

    /// Evaluate EQ / NE operators. `==` on a List or Map is identity in Dart,
    /// like `===` in the reference SDK: a condition and an attribute are decoded
    /// separately, so `$eq` is false and `$ne` true for them whatever the
    /// contents. Plain equality (`{"tags": ["a"]}`) still compares contents.
    if (operator == "\$eq") return attributeValue == conditionValue;
    if (operator == "\$ne") return attributeValue != conditionValue;

    /// Evaluate version operators. Any operand without a version of its own
    /// (absent, null, boolean, empty string, array, object) compares as "0".
    switch (operator) {
      case "\$veq":
      case "\$vne":
      case "\$vgt":
      case "\$vgte":
      case "\$vlt":
      case "\$vlte":
        final source =
            GBUtils.paddedVersionString(_versionInput(attributeValue));
        final target =
            GBUtils.paddedVersionString(_versionInput(conditionValue));
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

    /// Evaluate the range operators through one rule mirroring JavaScript's
    /// relational comparison (see [_rangeComparison]). They are dispatched on
    /// the operator alone so a condition value of any shape reaches them; an
    /// array or object attribute is not compared.
    switch (operator) {
      case "\$lt":
      case "\$lte":
      case "\$gt":
      case "\$gte":
        if (attributeValue is List || attributeValue is Map) return false;
        final order = _rangeComparison(attributeValue, conditionValue);
        if (order == null) return false;
        switch (operator) {
          case "\$lt":
            return order < 0;
          case "\$lte":
            return order <= 0;
          case "\$gt":
            return order > 0;
          default:
            return order >= 0;
        }
    }

    /// There are three operators where conditionValue is an array
    if (conditionValue is List) {
      switch (operator) {
        case '\$in':
          return isIn(attributeValue, conditionValue);

        /// Evaluate INI operator - case-insensitive version of $in
        case '\$ini':
          return isIn(attributeValue, conditionValue, inSensitive: true);

        /// Evaluate NIN operator - attributeValue not in the conditionValue
        /// array.
        case '\$nin':
          return !isIn(attributeValue, conditionValue);

        /// Evaluate NINI operator - case-insensitive version of $nin
        case '\$nini':
          return !isIn(attributeValue, conditionValue, inSensitive: true);

        /// Evaluate ALL operator - whether condition contains all attribute
        case '\$all':
          return _isInAll(attributeValue, conditionValue, savedGroups,
              visited: visited);

        /// Evaluate ALLI operator - case-insensitive version of $all
        case '\$alli':
          return _isInAll(attributeValue, conditionValue, savedGroups,
              inSensitive: true, visited: visited);
        default:
          return false;
      }
    } else if (attributeValue is List) {
      switch (operator) {
        /// Evaluate ELEMENT-MATCH operator - whether condition matches attribute
        case "\$elemMatch":
          return elemMatch(attributeValue, conditionValue, savedGroups,
              visited: visited);

        /// Evaluate SIE operator - whether condition size is same as that
        /// of attribute
        case "\$size":
          return isEvalConditionValue(
              conditionValue, attributeValue.length, savedGroups,
              visited: visited);

        default:
      }
    }
    return false;
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
    required Set<String> visited,
  }) {
    if (attributeValue is! List) return false;
    for (final condition in conditionValue) {
      var passed = false;
      for (final attribute in attributeValue) {
        if (isEvalConditionValue(condition, attribute, savedGroups,
            inSensitive: inSensitive, visited: visited)) {
          passed = true;
          break;
        }
      }
      if (!passed) return false;
    }
    return true;
  }

  /// Matches [attributeValue], already converted by [_regexInput], against
  /// [pattern]; [negate] selects the `$notRegex` / `$notRegexi` polarity.
  bool _evalRegex({
    required dynamic pattern,
    required String? attributeValue,
    required bool isCaseSensitive,
    required bool negate,
  }) {
    // An unusable pattern fails both polarities, negated or not. That is the
    // reference SDK's contract too: it wraps the match in a try/catch that
    // returns false, and a non-string pattern throws on its way into RegExp.
    if (pattern is! String) return false;

    // An absent or null attribute matches no pattern, and therefore does
    // not-match every one, so the pair stays a strict negation
    if (attributeValue == null) return negate;
    try {
      final regex = RegExp(pattern, caseSensitive: isCaseSensitive);
      final matches = regex.hasMatch(attributeValue);
      return negate != matches;
    } catch (_) {
      return false;
    }
  }

  /// Resolves a `$savedGroup` reference (`savedGroupReferencesV2`): is the user
  /// a member of the group it names?
  ///
  /// [reference] is `{"id": ..., "attributeKey"?: ...}`. Unlike `$inGroup`, the
  /// operator has no attribute of its own, so the entry decides what membership
  /// means — a `list` entry names the attribute to test, and a `condition` entry
  /// is evaluated in full and may itself reference further groups.
  ///
  /// Anything this SDK cannot make sense of matches nobody rather than
  /// throwing: a payload is allowed to be newer than the SDK reading it, and a
  /// group type added later must neither crash the host app nor quietly let
  /// everyone through.
  ///
  /// [visited] holds the ids currently being resolved, so a group that
  /// references itself — directly or along a chain — stops instead of
  /// recursing forever.
  bool _evalSavedGroup(Map<String, dynamic> attributes, dynamic reference,
      SavedGroupsValues savedGroups, Set<String> visited) {
    // The operator takes an object; a bare id string or an array is not one
    if (reference is! Map) return false;

    final id = reference['id'];
    if (id is! String || visited.contains(id)) return false;

    // An override that is present but unusable is not ignored: falling back to
    // the entry's own attribute would test a different population than the
    // payload asked for
    // `"attributeKey": null` counts as present too, as in the reference SDK
    // (`attributeKey !== undefined`); `reference[key]` answers null for both,
    // hence `containsKey`.
    final overrideKey = reference['attributeKey'];
    if (reference.containsKey('attributeKey') && overrideKey is! String) {
      return false;
    }

    // Absent from the payload, or a v1 bare array, which carries neither a type
    // to act on nor an attribute for this operator to use
    final entry = savedGroups[id];
    if (entry is! Map) return false;

    switch (entry['type']) {
      case 'list':
        // The override wins over the entry's own attribute
        final key = overrideKey ?? entry['attributeKey'];
        final values = entry['values'];
        if (key is! String || values is! List) return false;
        return isIn(getPath(attributes, key), values);

      // A condition group has no single attribute, so an override has nothing
      // to override
      case 'condition':
        final condition = entry['condition'];
        if (condition is! Map<String, dynamic>) return false;

        // A new set rather than `visited.add(id)`: sibling branches of an
        // `$or` / `$and` must not see each other's ids, and the default
        // `const {}` is unmodifiable
        return isEvalCondition(attributes, condition, savedGroups,
            visited: {...visited, id});

      // A group type added after this SDK was built
      default:
        return false;
    }
  }

  /// The values `$inGroup` / `$notInGroup` compare against, or null when the
  /// entry carries none and both operators must therefore fail closed.
  ///
  /// A `savedGroups` entry is either the v1 bare array these operators were
  /// built for, or a `savedGroupReferencesV2` typed entry. Only the `list`
  /// flavour of the latter has values to offer: a `condition` group is resolved
  /// through `$savedGroup`.
  ///
  /// An id absent from the payload is an empty group rather than null, so
  /// `$notInGroup` keeps passing for it — documented behaviour shared by every
  /// GrowthBook SDK. An id present with a `null` value is not absent: it is a
  /// malformed entry and fails closed, like the reference SDK's `undefined` /
  /// `null` split. `savedGroups[id]` answers null for both, hence `containsKey`.
  List<dynamic>? _savedGroupListValues(
      SavedGroupsValues savedGroups, dynamic id) {
    if (!savedGroups.containsKey(id)) return const [];
    final entry = savedGroups[id];

    // v1: a bare array of values
    if (entry is List) return entry;

    // v2: a typed list entry
    if (entry is Map && entry['type'] == 'list') {
      final values = entry['values'];
      return values is List ? values : null;
    }

    // A condition group, an unknown type, a null value, or not an object at all
    return null;
  }

  /// The text a `$regex` family operand is matched against, or null if it has none.
  ///
  /// The reference SDK hands the attribute to `RegExp.prototype.test`, which
  /// converts whatever it gets with JavaScript's `String(value)`, so the same
  /// conversion is reproduced here: an array is matched as its elements joined
  /// by commas (`["internal", "beta"]` -> `"internal,beta"`), an object as
  /// `"[object Object]"`.
  ///
  /// `null` is the one deliberate exception: JavaScript renders it as "null",
  /// which lets a pattern like `ull` match a user who does not have the
  /// attribute at all — an artefact of the conversion rather than intended
  /// targeting, and not pinned by the shared test cases.
  String? _regexInput(dynamic value) {
    if (value == null) return null;
    return _jsText(value);
  }

  /// The text a version operator (`$veq`, `$vgt`, ...) pads and compares.
  ///
  /// Follows the reference SDK's `paddedVersionString`: a number is converted
  /// to its string form, so an attribute sent as a JSON number (e.g. a build
  /// number) still matches, and anything without a version of its own compares
  /// as version "0".
  String _versionInput(dynamic value) {
    if (value is num) return _numberText(value);
    if (value is String && value.isNotEmpty) return value;
    // Absent, null, boolean, empty string, array, object
    return '0';
  }

  /// A number rendered as the reference SDK's single number type would render it:
  /// an integral value carries no fractional part (`10`, not `10.0`), matching
  /// `String(10.0) === "10"` in JavaScript.
  ///
  /// An `int` is printed as it is rather than routed through `double`, which
  /// would rewrite the digits of an id past 2^53. A double too large to be an
  /// exact integer keeps Dart's own notation; nothing sane targets a
  /// version or a pattern at such a value.
  String _numberText(num value) {
    if (value is int) return value.toString();
    // Beyond 2^53 a double is no longer an exact integer; keep its own notation
    if (value.isFinite &&
        value.abs() <= 9007199254740992 &&
        value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// JavaScript's `String(value)` for a decoded JSON value.
  String _jsText(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return value;
    if (value is num) return _numberText(value);
    if (value is bool) return value.toString();
    // Array.prototype.join: a null element renders as empty, a nested array
    // flattens into the same comma-separated text
    if (value is List) {
      return value.map((e) => e == null ? '' : _jsText(e)).join(',');
    }
    return '[object Object]';
  }

  /// The sign of `actual - expected` under JavaScript's relational comparison,
  /// or null when no direction holds.
  ///
  /// Two strings compare as text; Dart's `compareTo` orders by UTF-16 code unit,
  /// as JavaScript does. Anything else is converted with `Number()` first, and a
  /// value with no numeric reading is `NaN`, which no comparison satisfies. It
  /// used to become 0, so `"abc" < 1` passed, and a boolean was 0 either way.
  int? _rangeComparison(dynamic actual, dynamic expected) {
    if (actual is String && expected is String) {
      return actual.compareTo(expected).sign;
    }
    final a = _jsNumber(actual);
    final b = _jsNumber(expected);
    if (a.isNaN || b.isNaN) return null;
    return a.compareTo(b).sign;
  }

  /// JavaScript's `Number(value)` for a decoded JSON value.
  double _jsNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is bool) return value ? 1 : 0;
    if (value is String) return _jsNumberFromString(value);
    // `Number([5])` is `Number("5")`: an array converts through its text
    if (value is List) return _jsNumberFromString(_jsText(value));
    return double.nan;
  }

  /// JavaScript's `Number(text)`. Dart's `double.tryParse` is not that: it
  /// rejects `0x10`, which JavaScript reads as 16, and reads `NaN` as a number.
  /// Surrounding whitespace is ignored and an empty string is 0, as in
  /// JavaScript.
  double _jsNumberFromString(String string) {
    final text = string.trim();
    if (text.isEmpty) return 0;
    if (_jsDecimalLiteral.hasMatch(text)) {
      if (text.endsWith('Infinity')) {
        return text.startsWith('-') ? double.negativeInfinity : double.infinity;
      }
      return double.tryParse(text) ?? double.nan;
    }
    final radix = switch (text.length >= 2 ? text.substring(0, 2) : '') {
      '0x' || '0X' => 16,
      '0o' || '0O' => 8,
      '0b' || '0B' => 2,
      _ => null,
    };
    if (radix == null) return double.nan;
    final digits = text.substring(2);
    if (digits.isEmpty) return double.nan;
    var result = 0.0;
    for (final char in digits.split('')) {
      final digit = int.tryParse(char, radix: 16);
      if (digit == null || digit >= radix) return double.nan;
      result = result * radix + digit;
    }
    return result;
  }

  /// JavaScript truthiness, for the reference SDK's boolean contexts: `false`,
  /// `0`, `NaN`, `""` and `null` are falsy; everything else, arrays and objects
  /// included, is truthy.
  bool _isJsTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0 && !value.isNaN;
    if (value is String) return value.isNotEmpty;
    return true;
  }
}
