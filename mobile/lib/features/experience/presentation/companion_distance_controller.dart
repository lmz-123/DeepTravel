import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/nearby_story_points.dart';
import '../application/trigger_engine.dart';
import '../domain/tour_runtime.dart';
import 'active_tour_controller.dart';
import 'experience_providers.dart';
import 'offline_package_controller.dart';

enum CompanionDistanceMode { automatic, manual }

class CompanionDistanceState {
  const CompanionDistanceState({
    this.points = const [],
    this.target,
    this.mode = CompanionDistanceMode.automatic,
    this.isLoading = false,
    this.error,
    this.hasLocation = false,
    this.allExplored = false,
    this.isPaused = false,
    this.isApproximate = false,
    this.locationIssue,
  });

  final List<NearbyStoryPoint> points;
  final NearbyStoryPoint? target;
  final CompanionDistanceMode mode;
  final bool isLoading;
  final Object? error;
  final bool hasLocation;
  final bool allExplored;
  final bool isPaused;
  final bool isApproximate;
  final String? locationIssue;
}

/// Injectable clock also makes expiry independent of the next GPS update.
final companionDistanceNowProvider =
    Provider<DateTime Function()>((ref) => () => DateTime.now().toUtc());

/// This selection is intentionally separate from the audio player's selection.
/// A non-disposing provider keeps the target while opening a route or profile.
final companionDistanceControllerProvider = NotifierProvider.family<
    CompanionDistanceController, CompanionDistanceState, String>(
  CompanionDistanceController.new,
);

class CompanionDistanceController extends Notifier<CompanionDistanceState> {
  CompanionDistanceController(this.routeSlug);

  // A distance estimate is not an arrival decision. Keep stricter accuracy
  // and freshness requirements in StableTriggerEngine unchanged.
  static const maximumDisplayAge = Duration(minutes: 1);
  static const maximumDisplayAccuracyM = 200.0;

  final String routeSlug;
  String? _manualId;
  String? _automaticId;
  String? _userId;
  String? _sessionId;
  bool _initialized = false;
  bool _wasLive = false;
  Timer? _expiry;

  @override
  CompanionDistanceState build() {
    final userId = ref.watch(currentUserIdProvider);
    final tour = ref.watch(activeTourControllerProvider);
    final sameRoute = tour.route?.slug == routeSlug;
    final sessionId = sameRoute ? tour.session?.id : null;
    final isLive = sessionId != null &&
        tour.status != 'idle' &&
        tour.status != 'stopped' &&
        tour.session?.isCompleted != true;
    if (_initialized &&
        (userId != _userId ||
            (_wasLive && (!isLive || sessionId != _sessionId)))) {
      _clearSelection();
    }
    _initialized = true;
    _userId = userId;
    _sessionId = sessionId;
    _wasLive = isLive;

    // A running tour already owns a usable manifest, including offline tours.
    final loaded = sameRoute && tour.route?.audioTour != null
        ? null
        : ref.watch(offlineAwareRouteProvider(routeSlug));
    final route = loaded?.asData?.value ?? (sameRoute ? tour.route : null);
    final now = ref.watch(companionDistanceNowProvider)();
    final rawSample =
        sameRoute && isLive && tour.locationMode == TourLocationMode.real
            ? tour.latestLocationSample
            : null;
    final sample = _validSample(rawSample, now) ? rawSample : null;
    _expiry?.cancel();
    if (sample != null) {
      final expiresIn =
          sample.recordedAt.add(maximumDisplayAge).difference(now);
      _expiry = Timer(expiresIn + const Duration(milliseconds: 1), () {
        // No new GPS event is needed to clear an obsolete number on screen.
        ref.invalidateSelf();
      });
    }
    ref.onDispose(() => _expiry?.cancel());

    final presence = {
      if (sameRoute)
        for (final point in tour.nearbyStoryPoints)
          point.fragment.id: point.status,
    };
    final projected = projectNearbyStoryPoints(
      manifestFragments: route?.audioTour?.fragments ?? const [],
      ledgerEntries: sameRoute ? tour.ledger?.entries ?? const [] : const [],
      presenceOf: (id) => switch (presence[id]) {
        NearbyStoryPointStatus.approaching => RegionPresence.candidate,
        NearbyStoryPointStatus.inRange => RegionPresence.inside,
        _ => RegionPresence.outside,
      },
      sample: sample,
    );
    final points = projected.map((point) {
      final region = point.fragment.triggerRegion;
      final usable = sample != null &&
          _validCoordinate(region.latitude, region.longitude) &&
          sample.accuracyM <= maximumDisplayAccuracyM &&
          point.distanceMeters?.isFinite == true;
      return NearbyStoryPoint(
        fragment: point.fragment,
        status: !usable && !_isExplored(point)
            ? NearbyStoryPointStatus.locationUnavailable
            : point.status,
        distanceMeters: usable ? point.distanceMeters : null,
      );
    }).toList();
    points.sort(_comparePoints);

    if (_manualId != null &&
        !points.any((point) => point.fragment.id == _manualId) &&
        route != null) {
      _manualId = null;
    }
    final automatic = _chooseAutomatic(points, sample);
    _automaticId = automatic?.fragment.id;
    final target = _manualId == null
        ? automatic
        : points.where((point) => point.fragment.id == _manualId).firstOrNull;
    return CompanionDistanceState(
      points: List.unmodifiable(points),
      target: target,
      mode: _manualId == null
          ? CompanionDistanceMode.automatic
          : CompanionDistanceMode.manual,
      isLoading: route == null && loaded?.isLoading == true,
      error: route == null ? loaded?.error : null,
      hasLocation: points.any((point) => point.distanceMeters != null),
      allExplored: points.isNotEmpty && points.every(_isExplored),
      isPaused: sameRoute && tour.status == 'paused',
      isApproximate: sample != null && sample.accuracyM > 50,
      locationIssue: rawSample == null
          ? null
          : rawSample.accuracyM > maximumDisplayAccuracyM
              ? '定位精度不足'
              : sample == null
                  ? '定位更新中'
                  : null,
    );
  }

  void selectPoint(String fragmentId) {
    if (!state.points.any((point) => point.fragment.id == fragmentId)) return;
    _manualId = fragmentId;
    ref.invalidateSelf();
  }

  void useAutomatic() {
    _clearSelection();
    ref.invalidateSelf();
  }

  /// Call when the user explicitly changes the selected companion route.
  void reset() => useAutomatic();

  void _clearSelection() {
    _manualId = null;
    _automaticId = null;
  }

  NearbyStoryPoint? _chooseAutomatic(
      List<NearbyStoryPoint> points, LocationSample? sample) {
    final previous =
        points.where((point) => point.fragment.id == _automaticId).firstOrNull;
    final unexplored = points.where((point) => !_isExplored(point)).toList();
    final candidates = unexplored.isEmpty ? points : unexplored;
    final nearest =
        candidates.where((point) => point.distanceMeters != null).firstOrNull;
    // Without a trustworthy position, never invent a new nearest place.
    if (nearest == null) {
      return candidates
              .any((point) => point.fragment.id == previous?.fragment.id)
          ? previous
          : null;
    }
    if (previous == null ||
        previous.distanceMeters == null ||
        !candidates.any((point) => point.fragment.id == previous.fragment.id)) {
      return nearest;
    }
    // Crossing a midpoint by a few metres should not keep changing the label.
    final threshold = math.max(
      math.max(25.0, sample?.accuracyM ?? 0),
      previous.distanceMeters! * .2,
    );
    return previous.distanceMeters! - nearest.distanceMeters! >= threshold
        ? nearest
        : previous;
  }

  static bool _isExplored(NearbyStoryPoint point) =>
      point.status == NearbyStoryPointStatus.triggered ||
      point.status == NearbyStoryPointStatus.heard;

  static bool _validCoordinate(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  static bool _validSample(LocationSample? sample, DateTime now) {
    if (sample == null ||
        !_validCoordinate(sample.latitude, sample.longitude) ||
        !sample.accuracyM.isFinite ||
        sample.accuracyM > maximumDisplayAccuracyM ||
        sample.accuracyM < 0) {
      return false;
    }
    final age = now.toUtc().difference(sample.recordedAt.toUtc());
    return age <= maximumDisplayAge &&
        age >= -StableTriggerEngine.maximumFutureSkew;
  }

  static int _comparePoints(NearbyStoryPoint left, NearbyStoryPoint right) {
    final a = left.distanceMeters;
    final b = right.distanceMeters;
    if (a != null && b != null) {
      final distance = a.compareTo(b);
      if (distance != 0) return distance;
    } else if (a != null || b != null) {
      return a != null ? -1 : 1;
    }
    final position = left.fragment.position.compareTo(right.fragment.position);
    return position != 0
        ? position
        : left.fragment.id.compareTo(right.fragment.id);
  }
}
