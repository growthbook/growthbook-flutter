import 'package:growthbook_sdk_flutter/src/Model/experiment.dart';

class ExperimentHelper {
  // Singleton instance
  static final ExperimentHelper shared = ExperimentHelper._();

  // Private set of tracked experiments
  final Set<String> _trackedExperiments = <String>{};

  // Private constructor for the singleton instance
  ExperimentHelper._();

  // Method to check if an experiment is already tracked
  bool isTracked(GBExperiment experiment, GBExperimentResult result) {
    // Generate the key based on the provided experiment and result
    String experimentKey = experiment.key;
    String key = '${result.hashAttribute ?? ""}'
        '${result.hashValue ?? ""}'
        '$experimentKey'
        '${result.variationID}';

    // Check if the key is already in the set of tracked experiments
    if (_trackedExperiments.contains(key)) {
      return true;
    }

    // Add the key to the set of tracked experiments
    _trackedExperiments.add(key);

    // Return false to indicate the experiment was not previously tracked
    return false;
  }
}
