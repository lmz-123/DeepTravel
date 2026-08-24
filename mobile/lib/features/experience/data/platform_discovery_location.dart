import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/discovery_location.dart';

typedef LocationDiagnosticCallback = void Function(
  String level,
  String message,
  Map<String, Object?> context,
);

typedef LocationServiceEnabledGetter = Future<bool> Function();
typedef LocationPermissionGetter = Future<LocationPermission> Function();
typedef CurrentPositionGetter = Future<Position> Function(
  LocationSettings settings,
);
typedef LastKnownPositionGetter = Future<Position?> Function(
  bool forceLocationManager,
);
typedef PlacemarkGetter = Future<List<Placemark>> Function(
  double latitude,
  double longitude,
);

class PlatformCurrentLocationSource implements CurrentLocationSource {
  PlatformCurrentLocationSource({
    this.onDiagnostic,
    LocationServiceEnabledGetter? locationServiceEnabled,
    LocationPermissionGetter? checkPermission,
    LocationPermissionGetter? requestPermission,
    CurrentPositionGetter? currentPosition,
    LastKnownPositionGetter? lastKnownPosition,
    PlacemarkGetter? placemarks,
  })  : _locationServiceEnabled =
            locationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
        _checkPermission = checkPermission ?? Geolocator.checkPermission,
        _requestPermission = requestPermission ?? Geolocator.requestPermission,
        _currentPosition = currentPosition ??
            ((settings) => Geolocator.getCurrentPosition(
                  locationSettings: settings,
                )),
        _lastKnownPosition = lastKnownPosition ??
            ((forceLocationManager) => Geolocator.getLastKnownPosition(
                  forceAndroidLocationManager: forceLocationManager,
                )),
        _placemarks = placemarks ?? placemarkFromCoordinates;

  static const _positionTimeout = Duration(seconds: 10);
  static const _localityTimeout = Duration(seconds: 8);
  static const _maximumCachedAge = Duration(seconds: 30);

  final LocationDiagnosticCallback? onDiagnostic;
  final LocationServiceEnabledGetter _locationServiceEnabled;
  final LocationPermissionGetter _checkPermission;
  final LocationPermissionGetter _requestPermission;
  final CurrentPositionGetter _currentPosition;
  final LastKnownPositionGetter _lastKnownPosition;
  final PlacemarkGetter _placemarks;

  @override
  Future<DiscoveryPermissionState> permissionState() async {
    if (!await _locationServiceEnabled()) {
      return DiscoveryPermissionState.serviceDisabled;
    }
    return _permissionState(await _checkPermission());
  }

  @override
  Future<DiscoveryLocationSample> currentPosition({
    required bool requestPermission,
  }) async {
    if (!await _locationServiceEnabled()) {
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.serviceDisabled,
      );
    }
    var permission = await _checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await _requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.deniedForever,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.denied,
      );
    }
    final stopwatch = Stopwatch()..start();
    try {
      final acquired = await _acquirePosition();
      final position = acquired.position;
      final localities = <String>[];
      try {
        final places = await _placemarks(
          position.latitude,
          position.longitude,
        ).timeout(_localityTimeout);
        for (final place in places) {
          for (final value in [
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ]) {
            final normalized = value?.trim();
            if (normalized != null &&
                normalized.isNotEmpty &&
                !localities.contains(normalized)) {
              localities.add(normalized);
            }
          }
        }
        _diagnostic('info', 'discovery_geocoder_completed', {
          'elapsed_ms': stopwatch.elapsedMilliseconds,
          'result_count': places.length,
          'candidate_count': localities.length,
        });
      } on TimeoutException {
        _diagnostic('warning', 'discovery_geocoder_failed', {
          'failure_type': 'timeout',
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        });
      } catch (error) {
        _diagnostic('warning', 'discovery_geocoder_failed', {
          'failure_type': _failureType(error),
          'elapsed_ms': stopwatch.elapsedMilliseconds,
        });
      }
      _diagnostic('info', 'discovery_position_acquired', {
        'provider_strategy': acquired.strategy,
        'cached': acquired.cached,
        'accuracy_bucket': _accuracyBucket(position.accuracy),
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      return DiscoveryLocationSample(
        latitude: position.latitude,
        longitude: position.longitude,
        recordedAt: position.timestamp,
        locality: localities.firstOrNull,
        localityCandidates: List.unmodifiable(localities),
        accuracyMeters: position.accuracy,
        providerStrategy: acquired.strategy,
        isCached: acquired.cached,
      );
    } on TimeoutException {
      _diagnostic('warning', 'discovery_position_failed', {
        'failure_type': 'timeout',
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.timeout,
      );
    } on LocationServiceDisabledException {
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.serviceDisabled,
      );
    } on PermissionDeniedException {
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.denied,
      );
    } on DiscoveryLocationFailure {
      rethrow;
    } catch (error) {
      _diagnostic('warning', 'discovery_position_failed', {
        'failure_type': _failureType(error),
        'elapsed_ms': stopwatch.elapsedMilliseconds,
      });
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.unavailable,
      );
    }
  }

  Future<({Position position, String strategy, bool cached})>
      _acquirePosition() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      final position = await _currentPosition(
        const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: _positionTimeout,
        ),
      );
      return (position: position, strategy: 'platform_default', cached: false);
    }

    try {
      final position = await _currentPosition(
        AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
          timeLimit: _positionTimeout,
        ),
      );
      return (
        position: position,
        strategy: 'android_location_manager',
        cached: false,
      );
    } on LocationServiceDisabledException {
      rethrow;
    } on PermissionDeniedException {
      rethrow;
    } catch (error) {
      _diagnostic('warning', 'discovery_location_manager_failed', {
        'provider_strategy': 'android_location_manager',
        'failure_type': _failureType(error),
      });
    }

    final cached = await _lastKnownPosition(true);
    if (cached != null && _isFreshCache(cached)) {
      return (
        position: cached,
        strategy: 'android_location_manager_cache',
        cached: true,
      );
    }
    throw TimeoutException('No fresh Android location was available');
  }

  bool _isFreshCache(Position position) {
    final age = DateTime.now().toUtc().difference(position.timestamp.toUtc());
    return age >= Duration.zero && age <= _maximumCachedAge;
  }

  void _diagnostic(
    String level,
    String message,
    Map<String, Object?> context,
  ) =>
      onDiagnostic?.call(level, message, context);

  String _failureType(Object error) => switch (error) {
        TimeoutException() => 'timeout',
        LocationServiceDisabledException() => 'service_disabled',
        PermissionDeniedException() => 'permission_denied',
        PositionUpdateException() => 'position_update',
        _ => error.runtimeType.toString(),
      };

  String _accuracyBucket(double accuracy) => switch (accuracy) {
        <= 10 => 'lte_10m',
        <= 25 => 'lte_25m',
        <= 50 => 'lte_50m',
        <= 100 => 'lte_100m',
        _ => 'gt_100m',
      };

  DiscoveryPermissionState _permissionState(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          DiscoveryPermissionState.granted,
        LocationPermission.deniedForever =>
          DiscoveryPermissionState.deniedForever,
        LocationPermission.denied => DiscoveryPermissionState.requestable,
        LocationPermission.unableToDetermine =>
          DiscoveryPermissionState.requestable,
      };
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
