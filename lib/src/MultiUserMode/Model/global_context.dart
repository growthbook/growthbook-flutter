import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';
import 'package:growthbook_sdk_flutter/src/MultiUserMode/constant.dart';

class GlobalContext {
  GlobalContext({
    this.features,
    this.savedGroups,
    this.experiments,
    this.onExperimentEvaluated,
  });

  /// Keys are unique identifiers for the features and the values are Feature objects.
  /// Feature definitions - To be pulled from API / Cache
  Map<String, dynamic>? features;

  SavedGroupsValues? savedGroups;

  List<GBExperiment>? experiments;

  /// Sink the evaluators report resolved experiments to.
  ///
  /// Experiments mostly reach users through feature rules, and `FeatureEvaluator`
  /// resolves those without the SDK ever seeing them. This is how the result
  /// travels back out, so the evaluators stay stateless — the state lives on the
  /// SDK that installed the sink.
  ExperimentEvalCallback? onExperimentEvaluated;
}
