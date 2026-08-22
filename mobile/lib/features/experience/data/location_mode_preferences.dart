import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tour_runtime.dart';

class SharedPreferencesLocationModeStore implements LocationModeStore {
  static const _key = 'tour_location_mode';

  @override
  Future<TourLocationMode> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key) == TourLocationMode.simulated.name
        ? TourLocationMode.simulated
        : TourLocationMode.real;
  }

  @override
  Future<void> write(TourLocationMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, mode.name);
  }
}
