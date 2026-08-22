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
      List<StoryFragment> fragments, Set<String> revealedIds) {
    final qualified = <({StoryFragment fragment, double distance})>[];
    for (final fragment in fragments) {
      if (_presence[fragment.id] == RegionPresence.acknowledged ||
          fragment.isCollected ||
          revealedIds.contains(fragment.id)) {
        continue;
      }
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
      qualified.add((fragment: fragment, distance: distance));
    }
    if (qualified.isEmpty) return null;
    qualified.sort((left, right) {
      final byDistance = left.distance.compareTo(right.distance);
      if (byDistance != 0) return byDistance;
      return left.fragment.position.compareTo(right.fragment.position);
    });
    return TriggerCandidate(fragment: qualified.first.fragment, sample: sample);
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
