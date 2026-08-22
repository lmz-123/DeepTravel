import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/location_mode_preferences.dart';
import '../domain/tour_runtime.dart';

final locationModeStoreProvider = Provider<LocationModeStore>(
  (ref) => SharedPreferencesLocationModeStore(),
);

class LocationModeController extends AsyncNotifier<TourLocationMode> {
  @override
  Future<TourLocationMode> build() async {
    if (!AppConfig.enableDemoTriggers) return TourLocationMode.real;
    return ref.watch(locationModeStoreProvider).read();
  }

  Future<void> setMode(TourLocationMode mode) async {
    final next = AppConfig.enableDemoTriggers ? mode : TourLocationMode.real;
    state = AsyncData(next);
    await ref.read(locationModeStoreProvider).write(next);
  }
}

final locationModeControllerProvider =
    AsyncNotifierProvider<LocationModeController, TourLocationMode>(
  LocationModeController.new,
);
