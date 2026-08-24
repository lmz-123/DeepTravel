import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/fragment_models.dart';
import '../domain/tour_runtime.dart';

typedef TourLocationDiagnosticCallback = void Function(
  String level,
  String message,
  Map<String, Object?> context,
);

typedef PositionStreamFactory = Stream<Position> Function(
  LocationSettings settings,
);

class GeolocatorTracker implements LocationTracker {
  GeolocatorTracker({
    this.onDiagnostic,
    PositionStreamFactory? positionStreamFactory,
  }) : _positionStreamFactory = positionStreamFactory ??
            ((settings) => Geolocator.getPositionStream(
                  locationSettings: settings,
                ));

  static const _androidUpdateTimeout = Duration(seconds: 12);

  final TourLocationDiagnosticCallback? onDiagnostic;
  final PositionStreamFactory _positionStreamFactory;
  StreamSubscription<Position>? _subscription;
  StreamController<LocationSample>? _controller;
  var _generation = 0;
  var _starting = false;

  @override
  Future<TourLocationPermission> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return TourLocationPermission.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return TourLocationPermission.deniedForever;
    }
    if (permission == LocationPermission.denied) {
      return TourLocationPermission.denied;
    }
    return TourLocationPermission.granted;
  }

  @override
  Stream<LocationSample> samples() {
    _controller ??= StreamController<LocationSample>.broadcast(onCancel: stop);
    if (_subscription == null && !_starting) {
      unawaited(_startStream());
    }
    return _controller!.stream;
  }

  Future<void> _startStream() async {
    final generation = ++_generation;
    _starting = true;
    await _subscription?.cancel();
    _subscription = null;
    if (generation != _generation) return;
    final strategy = defaultTargetPlatform == TargetPlatform.android
        ? 'android_location_manager'
        : 'platform_default';
    try {
      _subscription = _positionStreamFactory(
        _settings(),
      ).listen(
        (position) {
          if (generation != _generation) return;
          _diagnostic('info', 'journey_location_sample_received', {
            'provider_strategy': strategy,
            'accuracy_bucket': _accuracyBucket(position.accuracy),
          });
          _controller?.add(LocationSample(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyM: position.accuracy,
            recordedAt: position.timestamp,
          ));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (generation != _generation) return;
          _subscription = null;
          _diagnostic('warning', 'journey_location_stream_failed', {
            'provider_strategy': strategy,
            'failure_type': _failureType(error),
          });
          _controller?.addError(error, stackTrace);
        },
        onDone: () {
          if (generation == _generation) _subscription = null;
        },
      );
      _diagnostic('info', 'journey_location_stream_started', {
        'provider_strategy': strategy,
      });
    } catch (error, stackTrace) {
      if (generation != _generation) return;
      _diagnostic('warning', 'journey_location_stream_failed', {
        'provider_strategy': strategy,
        'failure_type': _failureType(error),
      });
      _controller?.addError(error, stackTrace);
    } finally {
      if (generation == _generation) _starting = false;
    }
  }

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 3),
        forceLocationManager: true,
        timeLimit: _androidUpdateTimeout,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '见地正在陪你行走',
          notificationText: '靠近线索时会自动播放故事，点按可回到旅程。',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.fitness,
          distanceFilter: 8,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true);
    }
    return const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 8);
  }

  void _diagnostic(
    String level,
    String message,
    Map<String, Object?> context,
  ) =>
      onDiagnostic?.call(level, message, context);

  String _failureType(Object error) => switch (error) {
        TimeoutException() => 'timeout',
        LocationServiceDisabledException() => 'service_disabled',
        PermissionDeniedException() => 'permission_denied',
        PositionUpdateException() => 'position_update',
        _ => error.runtimeType.toString(),
      };

  String _accuracyBucket(double accuracy) => switch (accuracy) {
        <= 10 => 'lte_10m',
        <= 25 => 'lte_25m',
        <= 50 => 'lte_50m',
        <= 100 => 'lte_100m',
        _ => 'gt_100m',
      };

  @override
  Future<void> stop() async {
    ++_generation;
    await _subscription?.cancel();
    _subscription = null;
    _starting = false;
  }
}

class JustAudioNarrationPlayer implements NarrationPlayer {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _noisy;
  StreamSubscription<AudioInterruptionEvent>? _interruptions;

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _noisy = session.becomingNoisyEventStream.listen((_) => _player.pause());
    _interruptions = session.interruptionEventStream.listen((event) {
      if (event.begin) _player.pause();
    });
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Stream<bool> get playingStream => _player.playerStateStream
      .map((state) =>
          state.playing && state.processingState != ProcessingState.completed)
      .distinct();
  @override
  Stream<bool> get completedStream => _player.playerStateStream
      .map((state) => state.processingState == ProcessingState.completed)
      .distinct();

  @override
  Future<void> play(StoryFragment fragment, {String? preparedPath}) async {
    final uri = preparedPath != null
        ? Uri.file(preparedPath)
        : Uri.parse(fragment.audio.url);
    await _player.setAudioSource(AudioSource.uri(uri,
        tag: MediaItem(
            id: fragment.id,
            album: '见地 · ${fragment.position}/5',
            title: fragment.title ?? fragment.safePreview,
            artist: '南头古城碎片导览')));
    // just_audio's play Future completes when playback pauses, stops, or
    // finishes. Do not await that lifecycle Future here: callers need control
    // back as soon as playback has started so they can bind live state.
    unawaited(_player.play().catchError((Object _, StackTrace __) {}));
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() => _player.play();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> replay() async {
    await _player.seek(Duration.zero);
    await _player.play();
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _noisy?.cancel();
    await _interruptions?.cancel();
    await _player.dispose();
  }
}

class ImagePickerCamera implements CameraCapture {
  final ImagePicker _picker = ImagePicker();
  @override
  Future<String?> capture() async => (await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          maxWidth: 4096,
          maxHeight: 4096))
      ?.path;
}

bool preparedFileExists(String? path, int expectedBytes) {
  if (path == null) return false;
  final file = File(path);
  return file.existsSync() &&
      (expectedBytes == 0 || file.lengthSync() == expectedBytes);
}
