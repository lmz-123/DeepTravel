import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_preferences_repository.dart';
import '../domain/tour_runtime.dart';
import '../../auth/presentation/auth_provider.dart';

final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>(
  (ref) => UserPreferencesRepository(),
);

final locationModeStoreProvider = Provider<LocationModeStore>(
  (ref) {
    final userId =
        ref.watch(authControllerProvider).asData?.value?.user.id ?? 'anonymous';
    return UserScopedLocationModeStore(
      ref.watch(userPreferencesRepositoryProvider),
      userId,
    );
  },
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
