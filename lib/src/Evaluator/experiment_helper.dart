import 'package:growthbook_sdk_flutter/src/Model/experiment.dart';
import 'package:growthbook_sdk_flutter/src/Model/experiment_result.dart';

/// Remembers which exposures have already been reported, so each one fires
/// the tracking callback and the plugins once.
///
/// Owned by a single SDK instance, never shared across the process: a shared
/// set let one instance — even one with no tracking plugin — mark an exposure
/// as reported, and every later instance then silently dropped it. It is not
/// reset on a user change either, because the key already carries
/// `hashAttribute`/`hashValue`; a fresh set per user would re-report an
/// exposure the previous one correctly remembered (A -> B -> A).
class ExperimentHelper {
  // Private set of tracked experiments
  final Set<String> _trackedExperiments = <String>{};

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
