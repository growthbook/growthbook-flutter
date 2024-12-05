/// An LRU Cache implementation to keep track of the most recent experiments.
class ExperimentTracker {
  static const int maxExperiments = 30;

  final Map<String, bool> trackedExperiments;

  ExperimentTracker({this.trackedExperiments = const <String, bool>{}});

  void trackExperiment(String experimentId) {
    trackedExperiments[experimentId] = true;

    if (trackedExperiments.length > maxExperiments) {
      trackedExperiments.remove(trackedExperiments.keys.first);
    }
  }

  bool isExperimentTracked(String experimentId) {
    return trackedExperiments.containsKey(experimentId);
  }

  void clearTrackedExperiments() {
    trackedExperiments.clear();
  }
}
