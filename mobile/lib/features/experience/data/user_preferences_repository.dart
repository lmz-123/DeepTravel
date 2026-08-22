import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tour_runtime.dart';

enum DownloadPolicy { wifiOnly, anyNetwork, manual }

class NormalizedOrbPosition {
  const NormalizedOrbPosition(this.x, this.y);

  final double x;
  final double y;

  NormalizedOrbPosition clamped() => NormalizedOrbPosition(
        x.clamp(0.0, 1.0).toDouble(),
        y.clamp(0.0, 1.0).toDouble(),
      );

  Offset resolve(Size availableSize, Size orbSize) {
    final bounds = Size(
      (availableSize.width - orbSize.width)
          .clamp(0, double.infinity)
          .toDouble(),
      (availableSize.height - orbSize.height)
          .clamp(0, double.infinity)
          .toDouble(),
    );
    final value = clamped();
    return Offset(value.x * bounds.width, value.y * bounds.height);
  }

  static NormalizedOrbPosition fromOffset(
    Offset offset,
    Size availableSize,
    Size orbSize,
  ) {
    final width = (availableSize.width - orbSize.width)
        .clamp(0, double.infinity)
        .toDouble();
    final height = (availableSize.height - orbSize.height)
        .clamp(0, double.infinity)
        .toDouble();
    return NormalizedOrbPosition(
      width == 0 ? 0 : (offset.dx / width).clamp(0.0, 1.0).toDouble(),
      height == 0 ? 0 : (offset.dy / height).clamp(0.0, 1.0).toDouble(),
    );
  }
}

class UserPreferencesRepository {
  UserPreferencesRepository({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;

  static const _prefix = 'traveler_preferences';
  static const _legacyLocationKey = 'tour_location_mode';
  static const _locationMigratedKey = 'traveler_preferences:location_migrated';
  final Future<SharedPreferences> Function() _preferences;

  String _key(String userId, String setting) => '$_prefix:$userId:$setting';

  Future<double> readPlaybackSpeed(String userId) async =>
      (await _preferences()).getDouble(_key(userId, 'playback_speed')) ?? 1.0;

  Future<void> writePlaybackSpeed(String userId, double speed) async {
    await (await _preferences()).setDouble(
      _key(userId, 'playback_speed'),
      speed.clamp(0.75, 2.0).toDouble(),
    );
  }

  Future<TourLocationMode> readLocationMode(String userId) async {
    final preferences = await _preferences();
    final key = _key(userId, 'location_mode');
    var value = preferences.getString(key);
    if (value == null && preferences.getBool(_locationMigratedKey) != true) {
      value = preferences.getString(_legacyLocationKey);
      if (value != null) await preferences.setString(key, value);
      await preferences.remove(_legacyLocationKey);
      await preferences.setBool(_locationMigratedKey, true);
    }
    return value == TourLocationMode.simulated.name
        ? TourLocationMode.simulated
        : TourLocationMode.real;
  }

  Future<void> writeLocationMode(String userId, TourLocationMode mode) async {
    await (await _preferences()).setString(
      _key(userId, 'location_mode'),
      mode.name,
    );
  }

  Future<DownloadPolicy> readDownloadPolicy(String userId) async {
    final value =
        (await _preferences()).getString(_key(userId, 'download_policy'));
    return DownloadPolicy.values.firstWhere(
      (item) => item.name == value,
      orElse: () => DownloadPolicy.wifiOnly,
    );
  }

  Future<void> writeDownloadPolicy(String userId, DownloadPolicy policy) async {
    await (await _preferences()).setString(
      _key(userId, 'download_policy'),
      policy.name,
    );
  }

  Future<NormalizedOrbPosition> readOrbPosition(String userId) async =>
      NormalizedOrbPosition(
        (await _preferences()).getDouble(_key(userId, 'orb_x')) ?? 1.0,
        (await _preferences()).getDouble(_key(userId, 'orb_y')) ?? 0.72,
      ).clamped();

  Future<void> writeOrbPosition(
      String userId, NormalizedOrbPosition position) async {
    final preferences = await _preferences();
    final value = position.clamped();
    await preferences.setDouble(_key(userId, 'orb_x'), value.x);
    await preferences.setDouble(_key(userId, 'orb_y'), value.y);
  }
}

class UserScopedLocationModeStore implements LocationModeStore {
  const UserScopedLocationModeStore(this.repository, this.userId);

  final UserPreferencesRepository repository;
  final String userId;

  @override
  Future<TourLocationMode> read() => repository.readLocationMode(userId);

  @override
  Future<void> write(TourLocationMode mode) =>
      repository.writeLocationMode(userId, mode);
}
