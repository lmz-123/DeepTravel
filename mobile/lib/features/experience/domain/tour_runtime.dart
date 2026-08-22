import 'dart:async';

import 'fragment_models.dart';

class LocationSample {
  const LocationSample(
      {required this.latitude,
      required this.longitude,
      required this.accuracyM,
      required this.recordedAt});
  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime recordedAt;
}

enum TourLocationPermission { granted, denied, deniedForever, serviceDisabled }

enum TourLocationMode { real, simulated }

abstract interface class LocationModeStore {
  Future<TourLocationMode> read();
  Future<void> write(TourLocationMode mode);
}

abstract interface class LocationTracker {
  Future<TourLocationPermission> requestPermission();
  Stream<LocationSample> samples();
  Future<void> stop();
}

abstract interface class NarrationPlayer {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<bool> get completedStream;
  Future<void> play(StoryFragment fragment, {String? preparedPath});
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> replay();
  Future<void> setSpeed(double speed);
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class CameraCapture {
  Future<String?> capture();
}

class OutboxEvent {
  const OutboxEvent(
      {required this.id, required this.type, required this.payload});
  final String id;
  final String type;
  final Map<String, dynamic> payload;
}

abstract interface class TourStore {
  Future<void> clearPrivateData();
  Future<void> saveJson(String key, Map<String, dynamic> value);
  Future<Map<String, dynamic>?> readJson(String key);
  Future<void> enqueue(OutboxEvent event);
  Future<List<OutboxEvent>> pending();
  Future<void> acknowledge(String id);
  Future<void> savePreparedAsset(
      String url, String path, String version, int sizeBytes);
  Future<String?> preparedAsset(String url, String version, int sizeBytes);
}
