import 'package:growthbook_sdk_flutter/growthbook_sdk_flutter.dart';

class GlobalContext {
  GlobalContext({
    this.features,
    this.savedGroups,
    this.experiments,
  });

  /// Keys are unique identifiers for the features and the values are Feature objects.
  /// Feature definitions - To be pulled from API / Cache
  Map<String, dynamic>? features;

  SavedGroupsValues? savedGroups;

  List<GBExperiment>? experiments;
}
