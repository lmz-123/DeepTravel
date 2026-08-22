import '../domain/tour_runtime.dart';
import 'user_preferences_repository.dart';

class SharedPreferencesLocationModeStore implements LocationModeStore {
  SharedPreferencesLocationModeStore({this.userId = 'default'})
      : _repository = UserPreferencesRepository();

  final String userId;
  final UserPreferencesRepository _repository;

  @override
  Future<TourLocationMode> read() async {
    return _repository.readLocationMode(userId);
  }

  @override
  Future<void> write(TourLocationMode mode) async {
    await _repository.writeLocationMode(userId, mode);
  }
}
