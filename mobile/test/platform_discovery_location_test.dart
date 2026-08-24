import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jiandi/features/experience/data/platform_discovery_location.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'Android uses bounded LocationManager and keeps coordinate on geocoder failure',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final settings = <LocationSettings>[];
    final diagnostics = <String>[];
    final source = PlatformCurrentLocationSource(
      locationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.whileInUse,
      requestPermission: () async => LocationPermission.whileInUse,
      currentPosition: (locationSettings) async {
        settings.add(locationSettings);
        return _position();
      },
      lastKnownPosition: (_) async => null,
      placemarks: (_, __) async => throw StateError('geocoder unavailable'),
      onDiagnostic: (_, message, __) => diagnostics.add(message),
    );

    final sample = await source.currentPosition(requestPermission: false);

    expect(sample.latitude, 22.54);
    expect(sample.longitude, 114.06);
    expect(sample.localityCandidates, isEmpty);
    expect(sample.providerStrategy, 'android_location_manager');
    expect(sample.isCached, isFalse);
    expect(settings, hasLength(1));
    expect((settings.single as AndroidSettings).forceLocationManager, isTrue);
    expect(settings.every((item) => item.timeLimit != null), isTrue);
    expect(diagnostics, contains('discovery_geocoder_failed'));
    expect(diagnostics, contains('discovery_position_acquired'));
  });

  test('Android accepts only a cache no older than thirty seconds', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final source = PlatformCurrentLocationSource(
      locationServiceEnabled: () async => true,
      checkPermission: () async => LocationPermission.whileInUse,
      requestPermission: () async => LocationPermission.whileInUse,
      currentPosition: (_) async => throw TimeoutException('provider timeout'),
      lastKnownPosition: (_) async => _position(
        timestamp: DateTime.now().toUtc().subtract(const Duration(seconds: 20)),
      ),
      placemarks: (_, __) async => <Placemark>[],
    );

    final sample = await source.currentPosition(requestPermission: false);

    expect(sample.isCached, isTrue);
    expect(sample.providerStrategy, 'android_location_manager_cache');
  });
}

Position _position({DateTime? timestamp}) => Position(
      longitude: 114.06,
      latitude: 22.54,
      timestamp: timestamp ?? DateTime.now().toUtc(),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
