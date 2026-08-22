import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_mode_preferences.dart';
import '../domain/tour_runtime.dart';

final locationModeStoreProvider = Provider<LocationModeStore>(
  (ref) => SharedPreferencesLocationModeStore(),
);

class LocationModeController extends AsyncNotifier<TourLocationMode> {
  @override
  Future<TourLocationMode> build() async {
    return ref.watch(locationModeStoreProvider).read();
  }

  Future<void> setMode(TourLocationMode mode) async {
    state = AsyncData(mode);
    await ref.read(locationModeStoreProvider).write(mode);
  }
}

final locationModeControllerProvider =
    AsyncNotifierProvider<LocationModeController, TourLocationMode>(
  LocationModeController.new,
);
