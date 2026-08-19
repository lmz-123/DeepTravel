import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/experience/domain/models.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;
}

class LocationService {
  Future<LocationCoordinates> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure('请先打开手机定位服务');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationFailure('需要定位权限才能确认到达当前站点');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LocationCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      throw const LocationFailure('暂时无法获取当前位置，请稍后重试');
    }
  }
}
