import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/runtime_log_reporter.dart';
import '../data/platform_tour_adapters.dart';
import '../domain/tour_runtime.dart';
import 'location_mode_controller.dart';

final routePreviewLocationTrackerProvider =
    Provider.autoDispose<LocationTracker>((ref) {
  final reporter = ref.watch(runtimeLogReporterProvider);
  final tracker = GeolocatorTracker(
    backgroundUpdatesEnabled: false,
    onDiagnostic: (level, message, context) {
      if (level == 'warning') {
        unawaited(reporter?.warning('location', message, context: context));
      } else {
        unawaited(reporter?.info('location', message, context: context));
      }
    },
  );
  ref.onDispose(() => unawaited(tracker.stop()));
  return tracker;
});

final routePreviewLocationProvider =
    StreamProvider.autoDispose<LocationSample>((ref) async* {
  final mode = await ref.watch(locationModeControllerProvider.future);
  if (mode != TourLocationMode.real) return;

  final tracker = ref.watch(routePreviewLocationTrackerProvider);
  final permission = await tracker.requestPermission();
  if (permission != TourLocationPermission.granted) return;

  yield* tracker.samples();
});
