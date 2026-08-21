import 'dart:math' as math;

import '../domain/fragment_models.dart';
import '../domain/tour_runtime.dart';

enum RegionPresence { outside, candidate, inside, acknowledged }

class TriggerCandidate {
  const TriggerCandidate({required this.fragment, required this.sample});
  final StoryFragment fragment;
  final LocationSample sample;
}

class StableTriggerEngine {
  final Map<String, RegionPresence> _presence = {};
  final Map<String, List<DateTime>> _qualifying = {};

  TriggerCandidate? process(LocationSample sample,
      List<StoryFragment> fragments, Set<String> collectedIds) {
    for (final fragment in fragments) {
      if (_presence[fragment.id] == RegionPresence.acknowledged ||
          fragment.isCollected) {
        continue;
      }
      if (!fragment.dependencyIds.every(collectedIds.contains)) continue;
      final region = fragment.triggerRegion;
      final distance = _distance(
          sample.latitude, sample.longitude, region.latitude, region.longitude);
      if (distance > region.exitRadiusM) {
        _presence[fragment.id] = RegionPresence.outside;
        _qualifying.remove(fragment.id);
        continue;
      }
      if (sample.accuracyM > region.maxAccuracyM ||
          distance > region.entryRadiusM) {
        continue;
      }
      final values = _qualifying.putIfAbsent(fragment.id, () => []);
      values.removeWhere((time) =>
          sample.recordedAt.difference(time) >
          Duration(seconds: region.sampleWindowSeconds));
      values.add(sample.recordedAt);
      if (values.length < region.qualifyingSamples) {
        _presence[fragment.id] = RegionPresence.candidate;
        continue;
      }
      _presence[fragment.id] = RegionPresence.inside;
      return TriggerCandidate(fragment: fragment, sample: sample);
    }
    return null;
  }

  void acknowledge(String fragmentId) {
    _presence[fragmentId] = RegionPresence.acknowledged;
    _qualifying.remove(fragmentId);
  }

  RegionPresence stateOf(String fragmentId) =>
      _presence[fragmentId] ?? RegionPresence.outside;

  static double _distance(double latA, double lonA, double latB, double lonB) {
    const radius = 6371000.0;
    final dLat = _radians(latB - latA);
    final dLon = _radians(lonB - lonA);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_radians(latA)) *
            math.cos(_radians(latB)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * radius * math.asin(math.sqrt(a));
  }

  static double _radians(double value) => value * math.pi / 180;
}
