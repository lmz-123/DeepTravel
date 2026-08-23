import 'dart:math' as math;

import '../domain/fragment_models.dart';
import '../domain/tour_runtime.dart';
import 'trigger_engine.dart';

enum NearbyStoryPointStatus {
  locationUnavailable,
  outside,
  approaching,
  inRange,
  triggered,
  heard,
}

class NearbyStoryPoint {
  const NearbyStoryPoint({
    required this.fragment,
    required this.status,
    this.distanceMeters,
  });

  final StoryFragment fragment;
  final NearbyStoryPointStatus status;
  final double? distanceMeters;

  bool get canReplay => fragment.isRevealed;
}

List<NearbyStoryPoint> projectNearbyStoryPoints({
  required List<StoryFragment> manifestFragments,
  required List<StoryFragment> ledgerEntries,
  required RegionPresence Function(String fragmentId) presenceOf,
  LocationSample? sample,
}) {
  final ledgerById = <String, StoryFragment>{
    for (final entry in ledgerEntries) entry.id: entry,
  };
  final points = manifestFragments.map((manifestFragment) {
    final ledgerEntry = ledgerById[manifestFragment.id];
    final fragment =
        ledgerEntry?.isRevealed == true ? ledgerEntry! : manifestFragment;
    final distance = sample == null
        ? null
        : _distanceMeters(
            sample.latitude,
            sample.longitude,
            fragment.triggerRegion.latitude,
            fragment.triggerRegion.longitude,
          );
    final status = switch (ledgerEntry) {
      StoryFragment(isCollected: true) => NearbyStoryPointStatus.heard,
      StoryFragment(isRevealed: true) => NearbyStoryPointStatus.triggered,
      _ when sample == null => NearbyStoryPointStatus.locationUnavailable,
      _ => switch (presenceOf(fragment.id)) {
          RegionPresence.inside ||
          RegionPresence.acknowledged =>
            NearbyStoryPointStatus.inRange,
          RegionPresence.candidate => NearbyStoryPointStatus.approaching,
          RegionPresence.outside => NearbyStoryPointStatus.outside,
        },
    };
    return NearbyStoryPoint(
      fragment: fragment,
      status: status,
      distanceMeters: distance,
    );
  }).toList();

  points.sort((left, right) {
    if (sample != null) {
      final byDistance = left.distanceMeters!.compareTo(right.distanceMeters!);
      if (byDistance != 0) return byDistance;
    }
    final byPosition =
        left.fragment.position.compareTo(right.fragment.position);
    if (byPosition != 0) return byPosition;
    return left.fragment.id.compareTo(right.fragment.id);
  });
  return points;
}

double _distanceMeters(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  const earthRadiusMeters = 6371000.0;
  final latitudeDelta = _radians(latitudeB - latitudeA);
  final longitudeDelta = _radians(longitudeB - longitudeA);
  final haversine = math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(_radians(latitudeA)) *
          math.cos(_radians(latitudeB)) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return 2 * earthRadiusMeters * math.asin(math.sqrt(haversine));
}

double _radians(double value) => value * math.pi / 180;
