import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/discovery_location.dart';

class PlatformCurrentLocationSource implements CurrentLocationSource {
  static const _positionTimeout = Duration(seconds: 15);
  static const _localityTimeout = Duration(seconds: 8);

  @override
  Future<DiscoveryPermissionState> permissionState() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return DiscoveryPermissionState.serviceDisabled;
    }
    return _permissionState(await Geolocator.checkPermission());
  }

  @override
  Future<DiscoveryLocationSample> currentPosition({
    required bool requestPermission,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.serviceDisabled,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
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
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      ).timeout(_positionTimeout);
      String? locality;
      try {
        final places = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(_localityTimeout);
        if (places.isNotEmpty) {
          final place = places.first;
          locality = _firstNonEmpty([
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ]);
        }
      } catch (_) {
        locality = null;
      }
      return DiscoveryLocationSample(
        latitude: position.latitude,
        longitude: position.longitude,
        recordedAt: position.timestamp,
        locality: locality,
      );
    } on TimeoutException {
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.timeout,
      );
    } on DiscoveryLocationFailure {
      rethrow;
    } catch (_) {
      throw const DiscoveryLocationFailure(
        DiscoveryLocationFailureReason.unavailable,
      );
    }
  }

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

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) return normalized;
    }
    return null;
  }
}
