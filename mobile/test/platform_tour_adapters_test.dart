import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jiandi/features/experience/data/platform_tour_adapters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android journey stream uses LocationManager directly', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final settings = <LocationSettings>[];
    final diagnostics = <String>[];
    final tracker = GeolocatorTracker(
      positionStreamFactory: (locationSettings) {
        settings.add(locationSettings);
        return Stream.value(_position());
      },
      onDiagnostic: (_, message, __) => diagnostics.add(message),
    );
    addTearDown(tracker.stop);

    final sample = await tracker.samples().first.timeout(
          const Duration(seconds: 2),
        );

    expect(sample.latitude, 22.54);
    expect(settings, hasLength(1));
    expect(settings.first, isA<AndroidSettings>());
    expect((settings.single as AndroidSettings).forceLocationManager, isTrue);
    expect(settings.single.distanceFilter, 3);
    expect(diagnostics, contains('journey_location_stream_started'));
  });
}

Position _position() => Position(
      longitude: 114.06,
      latitude: 22.54,
      timestamp: DateTime.now().toUtc(),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
