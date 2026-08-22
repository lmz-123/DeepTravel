import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logging/runtime_log_reporter.dart';
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
import 'location_mode_controller.dart';

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

enum EvidenceUploadPhase { captured, uploading, queued, accepted }

class EvidenceUploadState {
  const EvidenceUploadState({
    required this.filePath,
    required this.idempotencyKey,
    required this.phase,
    this.evidenceId,
  });

  final String filePath;
  final String idempotencyKey;
  final EvidenceUploadPhase phase;
  final String? evidenceId;

  EvidenceUploadState copyWith({
    EvidenceUploadPhase? phase,
    String? evidenceId,
  }) =>
      EvidenceUploadState(
        filePath: filePath,
        idempotencyKey: idempotencyKey,
        phase: phase ?? this.phase,
        evidenceId: evidenceId ?? this.evidenceId,
      );
}

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
    this.locationMode = TourLocationMode.real,
    this.locationMessage,
    this.errorMessage,
    this.evidenceUploads = const {},
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
  final TourLocationMode locationMode;
  final String? locationMessage;
  final String? errorMessage;
  final Map<String, EvidenceUploadState> evidenceUploads;

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
          TourLocationMode? locationMode,
          String? locationMessage,
          bool clearLocationMessage = false,
          String? errorMessage,
          bool clearError = false,
          Map<String, EvidenceUploadState>? evidenceUploads}) =>
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
        locationMode: locationMode ?? this.locationMode,
        locationMessage: clearLocationMessage
            ? null
            : locationMessage ?? this.locationMessage,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        evidenceUploads: evidenceUploads ?? this.evidenceUploads,
      );

  EvidenceUploadState? evidenceUploadFor(String fragmentId) =>
      evidenceUploads[fragmentId];
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
  String? _loadedFragmentId;

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
    await _stopLocationMonitoring();
    final locationMode = AppConfig.enableDemoTriggers
        ? await ref.read(locationModeControllerProvider.future)
        : TourLocationMode.real;
    state = ActiveTourState(
        status: 'preparing',
        route: route,
        session: session,
        locationMode: locationMode,
        isBusy: true);
    var prepared = <String, String>{};
    try {
      prepared = await ref.read(preparedRouteServiceProvider).prepare(manifest);
    } catch (_) {
      state = state.copyWith(locationMessage: '部分音频未下载，将在有网络时播放；文字稿仍可使用。');
    }
    TourLocationPermission? permission;
    if (locationMode == TourLocationMode.real) {
      permission = await ref.read(locationTrackerProvider).requestPermission();
    }
    final locationMessage = locationMode == TourLocationMode.simulated
        ? '模拟定位已开启：不会读取真实位置，请手动模拟到达下一条线索。'
        : _locationPermissionMessage(permission!);
    try {
      await _repository.startActiveTour(session.id);
      final ledger = await _repository.ledger(session.id);
      final restoredCurrent = _restorableCurrent(ledger);
      state = state.copyWith(
          status: locationMode == TourLocationMode.simulated
              ? 'simulated'
              : permission == TourLocationPermission.granted
                  ? 'monitoring'
                  : 'permission_limited',
          ledger: ledger,
          current: restoredCurrent,
          preparedPaths: prepared,
          isBusy: false,
          locationMessage:
              _restoredLocationMessage(restoredCurrent, locationMessage),
          clearError: true);
      await _store.saveJson('active_tour', {
        'journey_id': session.id,
        'route_slug': route.slug,
        'status': state.status,
        'location_mode': locationMode.name,
        'script_version': manifest.scriptVersion
      });
      await _store.saveJson('prepared_manifest_${route.slug}', {
        'script_version': manifest.scriptVersion,
        'download_size_bytes': manifest.downloadSizeBytes,
        'fragment_ids': manifest.fragments.map((item) => item.id).toList(),
        'prepared_fragment_ids': prepared.keys.toList(),
      });
      _bindPlayer();
      if (locationMode == TourLocationMode.real &&
          permission == TourLocationPermission.granted) {
        _listenToRealLocation();
      }
      await _restorePendingEvidence();
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
    if (state.locationMode != TourLocationMode.real ||
        state.status != 'monitoring' ||
        _triggering) {
      return;
    }
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
    final reporter = ref.read(runtimeLogReporterProvider);
    if (!AppConfig.enableDemoTriggers ||
        state.locationMode != TourLocationMode.simulated ||
        state.status != 'simulated' ||
        _triggering) {
      unawaited(reporter?.warning(
        'tour',
        'demo_arrival_ignored',
        context: {
          'demo_enabled': AppConfig.enableDemoTriggers,
          'location_mode': state.locationMode.name,
          'tour_status': state.status,
          'trigger_in_progress': _triggering,
        },
      ));
      return;
    }

    state = state.copyWith(
      isBusy: true,
      locationMessage: '正在确认下一条线索…',
      clearError: true,
    );
    unawaited(reporter?.info(
      'tour',
      'demo_arrival_tapped',
      context: {'tour_status': state.status},
    ));

    try {
      await _refreshLedger();
      final pendingNarration = _pendingNarration();
      if (pendingNarration != null) {
        state = state.copyWith(
          current: pendingNarration,
          locationMessage:
              state.isPlaying && _loadedFragmentId == pendingNarration.id
                  ? '第 ${pendingNarration.position} 条线索仍在播放，听完或阅读文字稿后即可继续。'
                  : '已恢复第 ${pendingNarration.position} 条线索，正在播放尚未完成的故事。',
        );
        if (_loadedFragmentId != pendingNarration.id) {
          unawaited(_playNarration(pendingNarration));
        } else if (!state.isPlaying) {
          unawaited(_player.resume());
        }
        unawaited(reporter?.info(
          'tour',
          'pending_narration_resumed',
          context: {
            'fragment_id': pendingNarration.id,
            'fragment_position': pendingNarration.position,
            'fragment_state': pendingNarration.state,
          },
        ));
        return;
      }

      final next = _nextDemoFragment();
      if (next == null) {
        state = state.copyWith(
          locationMessage: _demoBlockedMessage(),
        );
        unawaited(reporter?.warning(
          'tour',
          'demo_arrival_no_eligible_fragment',
          context: _ledgerStateSummary(),
        ));
        return;
      }
      final triggered = await _trigger(next, method: 'demo');
      if (triggered) {
        state = state.copyWith(locationMessage: '已到达新线索，正在准备播放故事。');
      }
    } catch (error, stackTrace) {
      state = state.copyWith(errorMessage: _message(error));
      unawaited(reporter?.error(
        'tour',
        'demo_arrival_failed',
        error: error,
        stackTrace: stackTrace,
      ));
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  StoryFragment? _nextDemoFragment() {
    final ledger = state.ledger;
    final manifest = state.route?.audioTour;
    if (ledger == null || manifest == null) return null;
    final collected = ledger.entries
        .where((value) => value.isCollected)
        .map((value) => value.id)
        .toSet();
    for (final fragment in manifest.fragments) {
      final entry =
          ledger.entries.where((value) => value.id == fragment.id).firstOrNull;
      if (entry?.state == 'undiscovered' &&
          fragment.dependencyIds.every(collected.contains)) {
        return fragment;
      }
    }
    return null;
  }

  StoryFragment? _pendingNarration() {
    final entries = state.ledger?.entries ?? const <StoryFragment>[];
    for (final entry in entries) {
      if (entry.isRevealed &&
          (entry.state == 'triggered' || entry.state == 'playing')) {
        return entry;
      }
    }
    return null;
  }

  StoryFragment? _restorableCurrent(StoryLedger ledger) {
    final revealed = ledger.entries.where((entry) => entry.isRevealed).toList()
      ..sort((left, right) => left.position.compareTo(right.position));
    for (final entry in revealed.reversed) {
      if (entry.state == 'triggered' || entry.state == 'playing') return entry;
    }
    for (final entry in revealed.reversed) {
      if (entry.isMissionPending) return entry;
    }
    return revealed.lastOrNull;
  }

  String _restoredLocationMessage(StoryFragment? restored, String fallback) {
    if (restored == null) return fallback;
    if (restored.state == 'triggered' || restored.state == 'playing') {
      return '已恢复第 ${restored.position} 条线索；音频和文字稿可继续查看。';
    }
    if (restored.isMissionPending) {
      return '已恢复第 ${restored.position} 条线索，现场照片仍待确认。';
    }
    return '已恢复第 ${restored.position} 条线索，可以继续寻找下一条。';
  }

  String _demoBlockedMessage() {
    final ledger = state.ledger;
    if (ledger == null) return '故事进度尚未加载，请稍后重试。';
    final missionPending =
        ledger.entries.where((entry) => entry.isMissionPending).firstOrNull;
    if (missionPending != null) {
      return '第 ${missionPending.position} 条线索的照片尚未由服务器确认，请完成上传后继续。';
    }
    if (ledger.collectedCount == ledger.totalCount) {
      return '所有线索已经收集完成，可以开始拼合完整故事。';
    }
    return '当前没有可触发的新线索，已重新同步进度；请查看线索簿中的未完成项。';
  }

  Map<String, Object?> _ledgerStateSummary() {
    final ledger = state.ledger;
    if (ledger == null) return const {'ledger_loaded': false};
    final counts = <String, int>{};
    for (final entry in ledger.entries) {
      counts[entry.state] = (counts[entry.state] ?? 0) + 1;
    }
    return {
      'ledger_loaded': true,
      'collected_count': ledger.collectedCount,
      'total_count': ledger.totalCount,
      'state_counts': counts.entries
          .map((entry) => '${entry.key}:${entry.value}')
          .join(','),
    };
  }

  Future<bool> _trigger(StoryFragment fragment,
      {required String method, LocationSample? sample}) async {
    final session = state.session;
    if (session == null) return false;
    final reporter = ref.read(runtimeLogReporterProvider);
    _triggering = true;
    final key = _uuid.v4();
    unawaited(reporter?.info(
      'tour',
      'fragment_trigger_requested',
      context: {
        'fragment_id': fragment.id,
        'fragment_position': fragment.position,
        'method': method,
      },
    ));
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
      unawaited(reporter?.info(
        'tour',
        'fragment_trigger_succeeded',
        context: {
          'fragment_id': fragment.id,
          'fragment_position': fragment.position,
          'method': method,
        },
      ));
      return true;
    } catch (error, stackTrace) {
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
      unawaited(reporter?.error(
        'tour',
        'fragment_trigger_failed',
        error: error,
        stackTrace: stackTrace,
        context: {
          'fragment_id': fragment.id,
          'fragment_position': fragment.position,
          'method': method,
        },
      ));
      return false;
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
    unawaited(_playNarration(fragment));
  }

  Future<void> _onNarrationCompleted() async {
    final completed = state.current;
    final session = state.session;
    if (completed == null || session == null) return;

    // just_audio keeps `playing == true` when playback naturally reaches the
    // completed processing state. Reset it immediately so the next trigger is
    // started instead of becoming stranded behind an already-finished item.
    StoryFragment? next;
    if (state.queue.isNotEmpty) {
      next = state.queue.first;
      state = state.copyWith(
        current: next,
        queue: state.queue.skip(1).toList(),
        isPlaying: false,
        position: Duration.zero,
      );
    } else {
      state = state.copyWith(
        isPlaying: false,
        position: state.duration ?? state.position,
      );
    }
    await _persistNarrationQueue();
    if (next != null) unawaited(_playNarration(next));

    final key = _uuid.v4();
    try {
      await _repository.acknowledgePlayback(session.id, completed.id, 1, key);
      await _refreshLedger();
    } catch (_) {
      await _store.enqueue(OutboxEvent(id: key, type: 'playback', payload: {
        'journey_id': session.id,
        'fragment_id': completed.id,
        'progress': 1.0
      }));
    }
  }

  Future<void> _playNarration(StoryFragment fragment) async {
    try {
      _loadedFragmentId = fragment.id;
      await _player.play(
        fragment,
        preparedPath: state.preparedPaths[fragment.id],
      );
    } catch (error, stackTrace) {
      if (_loadedFragmentId == fragment.id) _loadedFragmentId = null;
      state = state.copyWith(
        isPlaying: false,
        errorMessage: '故事音频暂时无法播放，可以先查看文字稿后重试。',
      );
      unawaited(ref.read(runtimeLogReporterProvider)?.error(
        'audio',
        'narration_playback_failed',
        error: error,
        stackTrace: stackTrace,
        context: {
          'fragment_id': fragment.id,
          'fragment_position': fragment.position,
        },
      ));
    }
  }

  Future<void> captureEvidence(StoryFragment fragment) async {
    final path = await ref.read(cameraCaptureProvider).capture();
    if (path == null) {
      state = state.copyWith(locationMessage: '拍照任务已保留，可以在安全方便时再完成。');
      return;
    }
    final upload = EvidenceUploadState(
      filePath: path,
      idempotencyKey: _uuid.v4(),
      phase: EvidenceUploadPhase.captured,
    );
    state = state.copyWith(evidenceUploads: {
      ...state.evidenceUploads,
      fragment.id: upload,
    });
    await _persistEvidenceUpload(fragment.id, upload);
    await submitPendingEvidence(fragment);
  }

  Future<void> submitPendingEvidence(StoryFragment fragment) async {
    final session = state.session;
    final upload = state.evidenceUploadFor(fragment.id);
    if (session == null || upload == null) return;
    _setEvidenceUpload(
        fragment.id, upload.copyWith(phase: EvidenceUploadPhase.uploading));
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final evidence = await _repository.uploadEvidence(
          session.id, fragment.id, upload.filePath, upload.idempotencyKey);
      await _refreshLedger();
      _acceptEvidenceUpload(fragment.id, upload, evidence.id);
      await _store.saveJson('pending_evidence_${fragment.id}', {
        'state': 'accepted',
        'file_path': upload.filePath,
        'idempotency_key': upload.idempotencyKey,
        'evidence_id': evidence.id,
      });
      state = state.copyWith(
          isBusy: false, locationMessage: '现场照片已私密保存并完成确认，可以继续寻找下一条线索。');
      final reporter = ref.read(runtimeLogReporterProvider);
      if (reporter != null) {
        unawaited(reporter.info(
          'evidence',
          'photo_evidence_accepted',
          context: {'fragment_id': fragment.id},
        ));
      }
    } catch (error) {
      final accepted = await _confirmEvidenceAfterFailure(fragment.id);
      if (accepted != null) {
        _acceptEvidenceUpload(
            fragment.id, upload, accepted.evidenceId ?? 'confirmed');
        state = state.copyWith(
            isBusy: false, locationMessage: '现场照片已由服务器确认，可以继续寻找下一条线索。');
        return;
      }
      final queued = upload.copyWith(phase: EvidenceUploadPhase.queued);
      _setEvidenceUpload(fragment.id, queued);
      await _store.enqueue(
          OutboxEvent(id: upload.idempotencyKey, type: 'evidence', payload: {
        'journey_id': session.id,
        'fragment_id': fragment.id,
        'file_path': upload.filePath
      }));
      await _persistEvidenceUpload(fragment.id, queued);
      state = state.copyWith(
          isBusy: false,
          errorMessage: '照片仍在本机等待上传，确认完成前不会推进下一条线索。${_message(error)}');
      final reporter = ref.read(runtimeLogReporterProvider);
      if (reporter != null) {
        unawaited(reporter.warning(
          'evidence',
          'photo_evidence_queued',
          context: {'fragment_id': fragment.id},
        ));
      }
    }
  }

  Future<StoryFragment?> _confirmEvidenceAfterFailure(String fragmentId) async {
    try {
      await _refreshLedger();
      return state.ledger?.entries
          .where((entry) =>
              entry.id == fragmentId &&
              entry.isCollected &&
              entry.evidenceId != null)
          .firstOrNull;
    } catch (_) {
      return null;
    }
  }

  void _acceptEvidenceUpload(
      String fragmentId, EvidenceUploadState upload, String evidenceId) {
    _setEvidenceUpload(
        fragmentId,
        upload.copyWith(
            phase: EvidenceUploadPhase.accepted, evidenceId: evidenceId));
  }

  void _setEvidenceUpload(String fragmentId, EvidenceUploadState upload) {
    state = state.copyWith(evidenceUploads: {
      ...state.evidenceUploads,
      fragmentId: upload,
    });
  }

  Future<void> _persistEvidenceUpload(
      String fragmentId, EvidenceUploadState upload) async {
    await _store.saveJson('pending_evidence_$fragmentId', {
      'state': upload.phase.name,
      'file_path': upload.filePath,
      'idempotency_key': upload.idempotencyKey,
      if (upload.evidenceId != null) 'evidence_id': upload.evidenceId,
    });
  }

  Future<void> _restorePendingEvidence() async {
    final pending = await _store.pending();
    final restored = <String, EvidenceUploadState>{};
    for (final event in pending.where((item) => item.type == 'evidence')) {
      final fragmentId = event.payload['fragment_id'] as String?;
      final filePath = event.payload['file_path'] as String?;
      if (fragmentId == null || filePath == null) continue;
      restored[fragmentId] = EvidenceUploadState(
        filePath: filePath,
        idempotencyKey: event.id,
        phase: EvidenceUploadPhase.queued,
      );
    }
    if (restored.isNotEmpty) {
      state = state
          .copyWith(evidenceUploads: {...state.evidenceUploads, ...restored});
    }
  }

  Future<void> _refreshLedger() async {
    final session = state.session;
    if (session == null) return;
    final ledger = await _repository.ledger(session.id);
    StoryFragment? refreshedCurrent;
    final currentId = state.current?.id;
    if (currentId != null) {
      refreshedCurrent = ledger.entries
          .where((entry) => entry.id == currentId && entry.isRevealed)
          .firstOrNull;
    }
    refreshedCurrent ??= _restorableCurrent(ledger);
    state = state.copyWith(ledger: ledger, current: refreshedCurrent);
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
          final evidence = await _repository.uploadEvidence(
              payload['journey_id'] as String,
              payload['fragment_id'] as String,
              payload['file_path'] as String,
              event.id);
          final fragmentId = payload['fragment_id'] as String;
          final upload = state.evidenceUploadFor(fragmentId);
          if (upload != null) {
            _acceptEvidenceUpload(fragmentId, upload, evidence.id);
          }
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
    if (state.locationMode == TourLocationMode.simulated) {
      state = state.copyWith(
          status: 'simulated',
          locationMessage: '模拟定位已开启：不会读取真实位置，请手动模拟到达下一条线索。');
    } else if (_locations != null) {
      state = state.copyWith(
          status: 'monitoring', locationMessage: '定位正常，锁屏后会继续寻找附近线索');
    } else {
      await _activateRealLocation();
    }
    if (state.current != null) await _player.resume();
  }

  Future<void> setLocationMode(TourLocationMode mode) async {
    final effectiveMode =
        AppConfig.enableDemoTriggers ? mode : TourLocationMode.real;
    await ref
        .read(locationModeControllerProvider.notifier)
        .setMode(effectiveMode);
    await _stopLocationMonitoring();

    final paused = state.status == 'paused';
    final inactive = state.status == 'idle' || state.status == 'stopped';
    if (inactive) {
      state = state.copyWith(locationMode: effectiveMode);
      return;
    }
    if (effectiveMode == TourLocationMode.simulated) {
      state = state.copyWith(
          locationMode: effectiveMode,
          status: paused ? 'paused' : 'simulated',
          locationMessage: paused
              ? '已切换为模拟定位；继续导览后可手动模拟到达。'
              : '模拟定位已开启：不会读取真实位置，请手动模拟到达下一条线索。',
          clearError: true);
      await _persistLocationMode();
      return;
    }

    state = state.copyWith(
        locationMode: effectiveMode,
        locationMessage: paused ? '已切换为真实定位；继续导览时将申请定位权限。' : '正在启用真实定位…',
        clearError: true);
    if (!paused) await _activateRealLocation();
    await _persistLocationMode();
  }

  Future<void> stopTour() async {
    final session = state.session;
    await _stopLocationMonitoring();
    await _player.stop();
    _loadedFragmentId = null;
    if (session != null) await _repository.stopActiveTour(session.id);
    state = state.copyWith(
        status: 'stopped',
        isPlaying: false,
        locationMessage: '本次自动导览已停止，已收集线索仍会保留。');
  }

  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> replay() async {
    final current = state.current;
    if (current == null) return;
    if (_loadedFragmentId != current.id) {
      unawaited(_playNarration(current));
      return;
    }
    await _player.replay();
  }

  Future<void> togglePlayback() async {
    if (state.isPlaying) {
      await _player.pause();
      return;
    }
    final current = state.current;
    if (current == null) return;
    if (_loadedFragmentId != current.id) {
      unawaited(_playNarration(current));
      return;
    }
    await _player.resume();
  }

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

  Future<void> _activateRealLocation() async {
    try {
      final permission =
          await ref.read(locationTrackerProvider).requestPermission();
      state = state.copyWith(
          locationMode: TourLocationMode.real,
          status: permission == TourLocationPermission.granted
              ? 'monitoring'
              : 'permission_limited',
          locationMessage: _locationPermissionMessage(permission));
      if (permission == TourLocationPermission.granted) {
        _listenToRealLocation();
      }
    } catch (error) {
      state = state.copyWith(
          status: 'recoverable_error',
          errorMessage: _message(error),
          locationMessage: '真实定位暂时无法启动，请稍后重试。');
    }
  }

  void _listenToRealLocation() {
    _locations ??= ref.read(locationTrackerProvider).samples().listen(
          _onLocation,
          onError: (_) => state = state.copyWith(
              status: 'recoverable_error',
              locationMessage: '定位暂时中断，回到应用后会继续尝试'),
        );
  }

  Future<void> _stopLocationMonitoring() async {
    await _locations?.cancel();
    _locations = null;
    await ref.read(locationTrackerProvider).stop();
  }

  Future<void> _persistLocationMode() async {
    final session = state.session;
    final route = state.route;
    if (session == null || route == null) return;
    await _store.saveJson('active_tour', {
      'journey_id': session.id,
      'route_slug': route.slug,
      'status': state.status,
      'location_mode': state.locationMode.name,
      if (route.audioTour != null)
        'script_version': route.audioTour!.scriptVersion,
    });
  }

  String _locationPermissionMessage(TourLocationPermission permission) =>
      switch (permission) {
        TourLocationPermission.granted => '定位正常，锁屏后会继续寻找附近线索',
        TourLocationPermission.serviceDisabled => '系统定位未开启，自动触发暂停',
        TourLocationPermission.deniedForever => '定位权限已被系统阻止，可到设置开启或切换模拟定位',
        TourLocationPermission.denied => '未获得定位权限，可重试或切换模拟定位',
      };

  String _message(Object error) =>
      error is ExperienceFailure ? error.message : '操作未完成，请稍后重试';
}

final activeTourControllerProvider =
    NotifierProvider<ActiveTourController, ActiveTourState>(
        ActiveTourController.new);
