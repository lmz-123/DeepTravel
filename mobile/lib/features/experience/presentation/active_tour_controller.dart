import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../application/trigger_engine.dart';
import '../data/api_experience_repository.dart';
import '../data/local_tour_store.dart';
import '../data/platform_tour_adapters.dart';
import '../data/prepared_route_service.dart';
import '../domain/experience_repository.dart';
import '../domain/fragment_models.dart';
import '../domain/models.dart';
import '../domain/tour_runtime.dart';
import 'experience_providers.dart';

final tourStoreProvider = Provider<TourStore>((ref) => SqliteTourStore());
final locationTrackerProvider =
    Provider<LocationTracker>((ref) => GeolocatorTracker());
final cameraCaptureProvider =
    Provider<CameraCapture>((ref) => ImagePickerCamera());
final narrationPlayerProvider = Provider<NarrationPlayer>((ref) {
  final player = JustAudioNarrationPlayer();
  unawaited(player.initialize());
  ref.onDispose(player.dispose);
  return player;
});
final preparedRouteServiceProvider = Provider<PreparedRouteService>((ref) =>
    PreparedRouteService(ref.watch(dioProvider), ref.watch(tourStoreProvider)));

class ActiveTourState {
  const ActiveTourState({
    this.status = 'idle',
    this.route,
    this.session,
    this.ledger,
    this.current,
    this.queue = const [],
    this.preparedPaths = const {},
    this.isBusy = false,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1,
    this.locationMessage,
    this.errorMessage,
    this.pendingPhotoPath,
  });

  final String status;
  final RouteExperience? route;
  final JourneySession? session;
  final StoryLedger? ledger;
  final StoryFragment? current;
  final List<StoryFragment> queue;
  final Map<String, String> preparedPaths;
  final bool isBusy;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final double speed;
  final String? locationMessage;
  final String? errorMessage;
  final String? pendingPhotoPath;

  ActiveTourState copyWith(
          {String? status,
          RouteExperience? route,
          JourneySession? session,
          StoryLedger? ledger,
          StoryFragment? current,
          bool clearCurrent = false,
          List<StoryFragment>? queue,
          Map<String, String>? preparedPaths,
          bool? isBusy,
          bool? isPlaying,
          Duration? position,
          Duration? duration,
          double? speed,
          String? locationMessage,
          bool clearLocationMessage = false,
          String? errorMessage,
          bool clearError = false,
          String? pendingPhotoPath,
          bool clearPendingPhoto = false}) =>
      ActiveTourState(
        status: status ?? this.status,
        route: route ?? this.route,
        session: session ?? this.session,
        ledger: ledger ?? this.ledger,
        current: clearCurrent ? null : current ?? this.current,
        queue: queue ?? this.queue,
        preparedPaths: preparedPaths ?? this.preparedPaths,
        isBusy: isBusy ?? this.isBusy,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
        locationMessage: clearLocationMessage
            ? null
            : locationMessage ?? this.locationMessage,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        pendingPhotoPath: clearPendingPhoto
            ? null
            : pendingPhotoPath ?? this.pendingPhotoPath,
      );
}

class ActiveTourController extends Notifier<ActiveTourState> {
  final _triggerEngine = StableTriggerEngine();
  final _uuid = const Uuid();
  StreamSubscription<LocationSample>? _locations;
  StreamSubscription<bool>? _completed;
  StreamSubscription<bool>? _playing;
  StreamSubscription<Duration>? _position;
  StreamSubscription<Duration?>? _duration;
  bool _triggering = false;

  ExperienceRepository get _repository =>
      ref.read(experienceRepositoryProvider);
  TourStore get _store => ref.read(tourStoreProvider);
  NarrationPlayer get _player => ref.read(narrationPlayerProvider);

  @override
  ActiveTourState build() {
    ref.onDispose(() async {
      await _locations?.cancel();
      await _completed?.cancel();
      await _playing?.cancel();
      await _position?.cancel();
      await _duration?.cancel();
    });
    return const ActiveTourState();
  }

  Future<void> start(RouteExperience route, JourneySession session) async {
    if (state.session?.id == session.id && state.status != 'idle') return;
    final manifest = route.audioTour;
    if (manifest == null) return;
    state = ActiveTourState(
        status: 'preparing', route: route, session: session, isBusy: true);
    var prepared = <String, String>{};
    try {
      prepared = await ref.read(preparedRouteServiceProvider).prepare(manifest);
    } catch (_) {
      state = state.copyWith(locationMessage: '部分音频未下载，将在有网络时播放；文字稿仍可使用。');
    }
    final permission =
        await ref.read(locationTrackerProvider).requestPermission();
    final locationMessage = switch (permission) {
      TourLocationPermission.granted => '定位正常，锁屏后会继续寻找附近线索',
      TourLocationPermission.serviceDisabled => '系统定位未开启，自动触发暂停',
      TourLocationPermission.deniedForever => '定位权限已被系统阻止，可到设置开启或使用研究触发',
      TourLocationPermission.denied => '未获得定位权限，可使用研究触发体验故事',
    };
    try {
      await _repository.startActiveTour(session.id);
      final ledger = await _repository.ledger(session.id);
      state = state.copyWith(
          status: permission == TourLocationPermission.granted
              ? 'monitoring'
              : 'permission_limited',
          ledger: ledger,
          preparedPaths: prepared,
          isBusy: false,
          locationMessage: locationMessage,
          clearError: true);
      await _store.saveJson('active_tour', {
        'journey_id': session.id,
        'route_slug': route.slug,
        'status': state.status,
        'script_version': manifest.scriptVersion
      });
      await _store.saveJson('prepared_manifest_${route.slug}', {
        'script_version': manifest.scriptVersion,
        'download_size_bytes': manifest.downloadSizeBytes,
        'fragment_ids': manifest.fragments.map((item) => item.id).toList(),
        'prepared_fragment_ids': prepared.keys.toList(),
      });
      _bindPlayer();
      if (permission == TourLocationPermission.granted) {
        _locations = ref.read(locationTrackerProvider).samples().listen(
            _onLocation,
            onError: (_) => state = state.copyWith(
                status: 'recoverable_error',
                locationMessage: '定位暂时中断，回到应用后会继续尝试'));
      }
      unawaited(reconcileOutbox());
    } catch (error) {
      state = state.copyWith(
          status: 'recoverable_error',
          isBusy: false,
          errorMessage: _message(error));
    }
  }

  void _bindPlayer() {
    _completed ??= _player.completedStream
        .where((value) => value)
        .listen((_) => _onNarrationCompleted());
    _playing ??= _player.playingStream
        .listen((value) => state = state.copyWith(isPlaying: value));
    _position ??= _player.positionStream
        .listen((value) => state = state.copyWith(position: value));
    _duration ??= _player.durationStream
        .listen((value) => state = state.copyWith(duration: value));
  }

  Future<void> _onLocation(LocationSample sample) async {
    if (state.status != 'monitoring' || _triggering) return;
    final manifest = state.route?.audioTour;
    final ledger = state.ledger;
    if (manifest == null || ledger == null) return;
    final candidate = _triggerEngine.process(
        sample,
        manifest.fragments,
        ledger.entries
            .where((value) => value.isCollected)
            .map((value) => value.id)
            .toSet());
    if (candidate == null) return;
    await _trigger(candidate.fragment,
        method: 'location', sample: candidate.sample);
  }

  Future<void> triggerNextDemo() async {
    if (!AppConfig.enableDemoTriggers || _triggering) return;
    final ledger = state.ledger;
    if (ledger == null) return;
    final collected = ledger.entries
        .where((value) => value.isCollected)
        .map((value) => value.id)
        .toSet();
    StoryFragment? next;
    for (final fragment in state.route!.audioTour!.fragments) {
      final currentState =
          ledger.entries.firstWhere((value) => value.id == fragment.id).state;
      if (currentState == 'undiscovered' &&
          fragment.dependencyIds.every(collected.contains)) {
        next = fragment;
        break;
      }
    }
    if (next == null) {
      state = state.copyWith(locationMessage: '先完成待处理的拍照线索，再继续下一段故事。');
      return;
    }
    await _trigger(next, method: 'demo');
  }

  Future<void> _trigger(StoryFragment fragment,
      {required String method, LocationSample? sample}) async {
    final session = state.session;
    if (session == null) return;
    _triggering = true;
    final key = _uuid.v4();
    try {
      final revealed = await _repository.triggerFragment(
          session.id, fragment.id,
          method: method,
          idempotencyKey: key,
          latitude: sample?.latitude,
          longitude: sample?.longitude,
          accuracyM: sample?.accuracyM);
      _triggerEngine.acknowledge(fragment.id);
      await _enqueueNarration(revealed);
      await _refreshLedger();
    } catch (error) {
      if (method == 'location') {
        await _store.enqueue(OutboxEvent(id: key, type: 'trigger', payload: {
          'journey_id': session.id,
          'fragment_id': fragment.id,
          'method': method,
          'latitude': sample?.latitude,
          'longitude': sample?.longitude,
          'accuracy_m': sample?.accuracyM
        }));
        if (state.preparedPaths.containsKey(fragment.id)) {
          await _enqueueNarration(fragment);
        }
      }
      state = state.copyWith(errorMessage: _message(error));
    } finally {
      _triggering = false;
    }
  }

  Future<void> _enqueueNarration(StoryFragment fragment) async {
    if (state.current != null && state.isPlaying) {
      state = state.copyWith(queue: [...state.queue, fragment]);
      await _persistNarrationQueue();
      return;
    }
    state = state.copyWith(
        current: fragment, position: Duration.zero, clearError: true);
    await _persistNarrationQueue();
    unawaited(
        _player.play(fragment, preparedPath: state.preparedPaths[fragment.id]));
  }

  Future<void> _onNarrationCompleted() async {
    final current = state.current;
    final session = state.session;
    if (current == null || session == null) return;
    final key = _uuid.v4();
    try {
      await _repository.acknowledgePlayback(session.id, current.id, 1, key);
      await _refreshLedger();
    } catch (_) {
      await _store.enqueue(OutboxEvent(id: key, type: 'playback', payload: {
        'journey_id': session.id,
        'fragment_id': current.id,
        'progress': 1.0
      }));
    }
    if (state.queue.isNotEmpty) {
      final next = state.queue.first;
      state =
          state.copyWith(queue: state.queue.skip(1).toList(), current: next);
      await _persistNarrationQueue();
      unawaited(_player.play(next, preparedPath: state.preparedPaths[next.id]));
    }
  }

  Future<void> captureEvidence(StoryFragment fragment) async {
    final path = await ref.read(cameraCaptureProvider).capture();
    if (path == null) {
      state = state.copyWith(locationMessage: '拍照任务已保留，可以在安全方便时再完成。');
      return;
    }
    state = state.copyWith(pendingPhotoPath: path);
    await submitPendingEvidence(fragment);
  }

  Future<void> submitPendingEvidence(StoryFragment fragment) async {
    final session = state.session;
    final path = state.pendingPhotoPath;
    if (session == null || path == null) return;
    final key = _uuid.v4();
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _repository.uploadEvidence(session.id, fragment.id, path, key);
      state = state.copyWith(
          isBusy: false,
          clearPendingPhoto: true,
          locationMessage: '现场线索已私密保存，故事碎片已收集。');
      await _refreshLedger();
    } catch (error) {
      await _store.enqueue(OutboxEvent(id: key, type: 'evidence', payload: {
        'journey_id': session.id,
        'fragment_id': fragment.id,
        'file_path': path
      }));
      state = state.copyWith(
          isBusy: false, errorMessage: '照片已保存在本机，网络恢复后可重试。${_message(error)}');
    }
  }

  Future<void> _refreshLedger() async {
    final session = state.session;
    if (session == null) return;
    final ledger = await _repository.ledger(session.id);
    state = state.copyWith(ledger: ledger);
    await _store.saveJson('ledger_${session.id}', {
      'collected_count': ledger.collectedCount,
      'total_count': ledger.totalCount,
      'fragments': ledger.entries
          .map((item) => {
                'id': item.id,
                'state': item.state,
                'playback_progress': item.playbackProgress,
                'evidence_id': item.evidenceId,
              })
          .toList(),
      'updated_at': DateTime.now().toUtc().toIso8601String()
    });
  }

  Future<void> _persistNarrationQueue() async {
    final session = state.session;
    if (session == null) return;
    await _store.saveJson('narration_${session.id}', {
      'current_fragment_id': state.current?.id,
      'queued_fragment_ids': state.queue.map((item) => item.id).toList(),
      'is_playing': state.isPlaying,
    });
  }

  Future<void> reconcileOutbox() async {
    for (final event in await _store.pending()) {
      try {
        final payload = event.payload;
        if (event.type == 'trigger') {
          await _repository.triggerFragment(
              payload['journey_id'] as String, payload['fragment_id'] as String,
              method: payload['method'] as String,
              idempotencyKey: event.id,
              latitude: payload['latitude'] as double?,
              longitude: payload['longitude'] as double?,
              accuracyM: payload['accuracy_m'] as double?);
        } else if (event.type == 'playback') {
          await _repository.acknowledgePlayback(
              payload['journey_id'] as String,
              payload['fragment_id'] as String,
              (payload['progress'] as num).toDouble(),
              event.id);
        } else if (event.type == 'evidence') {
          await _repository.uploadEvidence(
              payload['journey_id'] as String,
              payload['fragment_id'] as String,
              payload['file_path'] as String,
              event.id);
        }
        await _store.acknowledge(event.id);
      } catch (_) {
        break;
      }
    }
    if (state.session != null) await _refreshLedger();
  }

  Future<void> pauseTour() async {
    await _player.pause();
    state =
        state.copyWith(status: 'paused', locationMessage: '自动故事已暂停，线索和照片不会丢失。');
  }

  Future<void> resumeTour() async {
    state = state.copyWith(status: 'monitoring', clearLocationMessage: true);
    if (state.current != null) await _player.resume();
  }

  Future<void> stopTour() async {
    final session = state.session;
    await ref.read(locationTrackerProvider).stop();
    await _player.stop();
    if (session != null) await _repository.stopActiveTour(session.id);
    state = state.copyWith(
        status: 'stopped',
        isPlaying: false,
        locationMessage: '本次自动导览已停止，已收集线索仍会保留。');
  }

  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> replay() => _player.replay();
  Future<void> togglePlayback() =>
      state.isPlaying ? _player.pause() : _player.resume();
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  Future<ReconstructionResult> reconstruct(List<String> relationships) async {
    final result =
        await _repository.reconstruct(state.session!.id, relationships);
    if (result.correct) await stopTour();
    return result;
  }

  Future<FragmentRecap> loadRecap() =>
      _repository.fragmentRecap(state.session!.id);

  String _message(Object error) =>
      error is ExperienceFailure ? error.message : '操作未完成，请稍后重试';
}

final activeTourControllerProvider =
    NotifierProvider<ActiveTourController, ActiveTourState>(
        ActiveTourController.new);
