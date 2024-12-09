import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/global_context.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/options.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/Model/user_context.dart';

class EvaluationContext {
  EvaluationContext({
    required this.globalContext,
    required this.userContext,
    required this.stackContext,
    required this.options,
  });

  GlobalContext globalContext;
  UserContext userContext;
  StackContext stackContext;
  Options options;
}

class StackContext {
  String? id;
  Set<String> evaluatedFeatures;

  StackContext({
    this.id,
    Set<String>? evaluatedFeatures,
  }) : evaluatedFeatures = evaluatedFeatures ?? <String>{};
}
