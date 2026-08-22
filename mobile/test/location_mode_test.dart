import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/data/location_mode_preferences.dart';
import 'package:jiandi/features/experience/data/prepared_route_service.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/journey_page.dart';
import 'package:jiandi/features/experience/presentation/location_mode_controller.dart';
import 'package:jiandi/features/experience/presentation/route_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('location mode defaults to real and survives store recreation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final first = SharedPreferencesLocationModeStore();
    expect(await first.read(), TourLocationMode.real);

    await first.write(TourLocationMode.simulated);

    final restored = SharedPreferencesLocationModeStore();
    expect(await restored.read(), TourLocationMode.simulated);
  });

  testWidgets('route setup exposes an explicit simulated location switch',
      (tester) async {
    final modeStore = _MemoryLocationModeStore(TourLocationMode.real);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        experienceRepositoryProvider.overrideWithValue(_FragmentRepository()),
        locationModeStoreProvider.overrideWithValue(modeStore),
      ],
      child: const MaterialApp(home: RouteDetailPage(slug: 'test-route')),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('模拟定位（测试）'), findsOneWidget);
    expect(find.text('使用 GPS，靠近地点自动触发'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(modeStore.mode, TourLocationMode.simulated);
    expect(find.text('忽略 GPS，用按钮模拟到达'), findsOneWidget);
  });

  test('simulated startup skips GPS and runtime switch restores real GPS',
      () async {
    final location = _RecordingLocationTracker();
    final store = _MemoryTourStore();
    final modeStore = _MemoryLocationModeStore(TourLocationMode.simulated);
    final repository = _FragmentRepository();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(location),
      narrationPlayerProvider.overrideWithValue(_SilentNarrationPlayer()),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(modeStore),
    ]);
    addTearDown(container.dispose);

    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(_route, _session);

    expect(container.read(activeTourControllerProvider).status, 'simulated');
    expect(location.permissionRequests, 0);
    expect(location.sampleSubscriptions, 0);

    await controller.setLocationMode(TourLocationMode.real);

    expect(container.read(activeTourControllerProvider).status, 'monitoring');
    expect(location.permissionRequests, 1);
    expect(location.sampleSubscriptions, 1);

    await controller.setLocationMode(TourLocationMode.simulated);

    final simulated = container.read(activeTourControllerProvider);
    expect(simulated.status, 'simulated');
    expect(simulated.locationMode, TourLocationMode.simulated);
    expect(location.stopCalls, greaterThanOrEqualTo(2));
    expect(modeStore.mode, TourLocationMode.simulated);
  });

  test(
      'completed narration resets playing state and the next simulated clue starts immediately',
      () async {
    final store = _MemoryTourStore();
    final player = _ControllableNarrationPlayer();
    final repository = _ProgressingFragmentRepository();
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });

    final subscription = container.listen(
      activeTourControllerProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(activeTourControllerProvider.notifier);

    await controller.start(_twoFragmentRoute, _session);
    await controller.triggerNextDemo();

    expect(player.playedFragmentIds, ['fragment-1']);
    expect(container.read(activeTourControllerProvider).isPlaying, isTrue);

    player.completeNaturally();
    await _waitUntil(() => repository.isCollected('fragment-1'));

    expect(container.read(activeTourControllerProvider).isPlaying, isFalse);

    await controller.triggerNextDemo();

    final state = container.read(activeTourControllerProvider);
    expect(player.playedFragmentIds, ['fragment-1', 'fragment-2']);
    expect(state.current?.id, 'fragment-2');
    expect(state.queue, isEmpty);
  });

  testWidgets(
      'restored triggered clue shows audio and transcript then advances to the next clue',
      (tester) async {
    final store = _MemoryTourStore();
    final player = _ControllableNarrationPlayer();
    final repository = _ProgressingFragmentRepository(initialStates: const {
      'fragment-1': 'collected',
      'fragment-2': 'triggered',
      'fragment-3': 'undiscovered',
    });
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
      locationTrackerProvider.overrideWithValue(_RecordingLocationTracker()),
      narrationPlayerProvider.overrideWithValue(player),
      tourStoreProvider.overrideWithValue(store),
      preparedRouteServiceProvider
          .overrideWithValue(_NoopPreparedRouteService(store)),
      locationModeStoreProvider.overrideWithValue(
          _MemoryLocationModeStore(TourLocationMode.simulated)),
    ]);
    addTearDown(() async {
      container.dispose();
      await player.dispose();
    });

    await container
        .read(journeyControllerProvider.notifier)
        .start(_threeFragmentRoute);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: JourneyPage(journeyId: 'journey-1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('第二条线索'), findsOneWidget);
    expect(find.text('阅读等价文字稿'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('阅读等价文字稿'));
    await tester.pumpAndSettle();
    expect(find.text('第二条线索的正文'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('继续'));
    await tester.tap(find.byTooltip('继续'));
    await tester.pump();
    expect(player.playedFragmentIds, ['fragment-2']);

    player.completeNaturally();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('模拟到达下一条线索'));
    await tester.tap(find.text('模拟到达下一条线索'));
    await tester.pumpAndSettle();

    expect(repository.isCollected('fragment-2'), isTrue);
    expect(player.playedFragmentIds, ['fragment-2', 'fragment-3']);
    expect(find.text('第三条线索'), findsOneWidget);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 30; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('condition was not reached');
}

const _region = TriggerRegion(
  latitude: 22.5381,
  longitude: 113.9227,
  entryRadiusM: 60,
  exitRadiusM: 90,
  maxAccuracyM: 50,
  qualifyingSamples: 2,
  sampleWindowSeconds: 15,
  cooldownSeconds: 120,
  auditState: 'in_review',
);

const _audio = NarrationAsset(
  url: 'https://example.test/fragment.m4a',
  mimeType: 'audio/mp4',
  sizeBytes: 0,
  scriptVersion: 'v1',
);

const _fragment = StoryFragment(
  id: 'fragment-1',
  position: 1,
  safePreview: '第一条线索',
  interactionType: 'passive',
  reviewState: 'in_review',
  triggerRegion: _region,
  audio: _audio,
);

const _secondFragment = StoryFragment(
  id: 'fragment-2',
  position: 2,
  safePreview: '第二条线索',
  interactionType: 'passive',
  reviewState: 'in_review',
  triggerRegion: _region,
  audio: _audio,
  dependencyIds: ['fragment-1'],
);

const _thirdFragment = StoryFragment(
  id: 'fragment-3',
  position: 3,
  safePreview: '第三条线索',
  interactionType: 'passive',
  reviewState: 'in_review',
  triggerRegion: _region,
  audio: _audio,
  dependencyIds: ['fragment-2'],
);

const _manifest = AudioTourManifest(
  title: '测试导览',
  centralQuestion: '中心为什么迁移？',
  scriptVersion: 'v1',
  reviewState: 'in_review',
  fieldAuditState: 'in_review',
  productionReady: false,
  demoLabel: '研究预览',
  contentMethod: '测试内容',
  downloadSizeBytes: 0,
  fragments: [_fragment],
);

const _route = RouteExperience(
  id: 'route-1',
  slug: 'test-route',
  title: '测试路线',
  subtitle: '测试',
  description: '测试',
  durationMinutes: 10,
  distanceKm: 1,
  difficulty: 'easy',
  theme: 'history',
  heroImage: '',
  contentStatus: 'in_review',
  stops: [],
  audioTour: _manifest,
);

const _twoFragmentManifest = AudioTourManifest(
  title: '测试导览',
  centralQuestion: '中心为什么迁移？',
  scriptVersion: 'v1',
  reviewState: 'in_review',
  fieldAuditState: 'in_review',
  productionReady: false,
  demoLabel: '研究预览',
  contentMethod: '测试内容',
  downloadSizeBytes: 0,
  fragments: [_fragment, _secondFragment],
);

const _twoFragmentRoute = RouteExperience(
  id: 'route-1',
  slug: 'test-route',
  title: '测试路线',
  subtitle: '测试',
  description: '测试',
  durationMinutes: 10,
  distanceKm: 1,
  difficulty: 'easy',
  theme: 'history',
  heroImage: '',
  contentStatus: 'in_review',
  stops: [],
  audioTour: _twoFragmentManifest,
);

const _threeFragmentManifest = AudioTourManifest(
  title: '测试导览',
  centralQuestion: '中心为什么迁移？',
  scriptVersion: 'v1',
  reviewState: 'in_review',
  fieldAuditState: 'in_review',
  productionReady: false,
  demoLabel: '研究预览',
  contentMethod: '测试内容',
  downloadSizeBytes: 0,
  fragments: [_fragment, _secondFragment, _thirdFragment],
);

const _threeFragmentRoute = RouteExperience(
  id: 'route-1',
  slug: 'test-route',
  title: '测试路线',
  subtitle: '测试',
  description: '测试',
  durationMinutes: 10,
  distanceKm: 1,
  difficulty: 'easy',
  theme: 'history',
  heroImage: '',
  contentStatus: 'in_review',
  stops: [],
  audioTour: _threeFragmentManifest,
);

const _session = JourneySession(
  id: 'journey-1',
  routeId: 'route-1',
  status: 'active',
  currentStopPosition: 1,
  arrivedStopId: null,
  answeredStopIds: {},
  progress: 0,
);

class _FragmentRepository extends DemoExperienceRepository {
  _FragmentRepository() : super(latency: Duration.zero);

  @override
  Future<void> startActiveTour(String journeyId) async {}

  @override
  Future<void> stopActiveTour(String journeyId) async {}

  @override
  Future<RouteExperience> routeBySlug(String slug) async => _route;

  @override
  Future<JourneySession> startOrResume(String routeId) async => _session;

  @override
  Future<StoryLedger> ledger(String journeyId) async => const StoryLedger(
        centralQuestion: '中心为什么迁移？',
        collectedCount: 0,
        totalCount: 1,
        reconstructionUnlocked: false,
        entries: [_fragment],
      );
}

class _ProgressingFragmentRepository extends _FragmentRepository {
  _ProgressingFragmentRepository({Map<String, String>? initialStates})
      : _states = Map<String, String>.from(initialStates ??
            const {
              'fragment-1': 'undiscovered',
              'fragment-2': 'undiscovered',
            });

  final Map<String, String> _states;

  bool isCollected(String fragmentId) => _states[fragmentId] == 'collected';

  @override
  Future<StoryFragment> triggerFragment(String journeyId, String fragmentId,
      {required String method,
      required String idempotencyKey,
      double? latitude,
      double? longitude,
      double? accuracyM}) async {
    _states[fragmentId] = 'triggered';
    return _fragmentWithState(fragmentId, 'triggered', revealed: true);
  }

  @override
  Future<StoryFragment> acknowledgePlayback(String journeyId, String fragmentId,
      double progress, String idempotencyKey) async {
    _states[fragmentId] = 'collected';
    return _fragmentWithState(fragmentId, 'collected', revealed: true);
  }

  @override
  Future<StoryLedger> ledger(String journeyId) async {
    final entries = _states.entries
        .map((entry) => _fragmentWithState(entry.key, entry.value,
            revealed: entry.value != 'undiscovered'))
        .toList();
    final collected = entries.where((entry) => entry.isCollected).length;
    return StoryLedger(
      centralQuestion: '中心为什么迁移？',
      collectedCount: collected,
      totalCount: entries.length,
      reconstructionUnlocked: collected == entries.length,
      entries: entries,
    );
  }

  StoryFragment _fragmentWithState(String id, String state,
      {required bool revealed}) {
    final source = [_fragment, _secondFragment, _thirdFragment]
        .firstWhere((fragment) => fragment.id == id);
    return StoryFragment(
      id: source.id,
      position: source.position,
      safePreview: source.safePreview,
      interactionType: source.interactionType,
      reviewState: source.reviewState,
      triggerRegion: source.triggerRegion,
      audio: source.audio,
      title: revealed ? source.safePreview : null,
      transcript: revealed ? '${source.safePreview}的正文' : null,
      state: state,
      dependencyIds: source.dependencyIds,
    );
  }
}

class _RecordingLocationTracker implements LocationTracker {
  int permissionRequests = 0;
  int sampleSubscriptions = 0;
  int stopCalls = 0;

  @override
  Future<TourLocationPermission> requestPermission() async {
    permissionRequests += 1;
    return TourLocationPermission.granted;
  }

  @override
  Stream<LocationSample> samples() {
    sampleSubscriptions += 1;
    return const Stream<LocationSample>.empty();
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}

class _MemoryLocationModeStore implements LocationModeStore {
  _MemoryLocationModeStore(this.mode);
  TourLocationMode mode;

  @override
  Future<TourLocationMode> read() async => mode;

  @override
  Future<void> write(TourLocationMode mode) async => this.mode = mode;
}

class _NoopPreparedRouteService extends PreparedRouteService {
  _NoopPreparedRouteService(TourStore store) : super(Dio(), store);

  @override
  Future<Map<String, String>> prepare(AudioTourManifest manifest) async => {};
}

class _MemoryTourStore implements TourStore {
  final snapshots = <String, Map<String, dynamic>>{};

  @override
  Future<void> acknowledge(String id) async {}

  @override
  Future<void> enqueue(OutboxEvent event) async {}

  @override
  Future<List<OutboxEvent>> pending() async => [];

  @override
  Future<String?> preparedAsset(
          String url, String version, int sizeBytes) async =>
      null;

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => snapshots[key];

  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {
    snapshots[key] = value;
  }

  @override
  Future<void> savePreparedAsset(
      String url, String path, String version, int sizeBytes) async {}
}

class _SilentNarrationPlayer implements NarrationPlayer {
  @override
  Stream<bool> get completedStream => const Stream<bool>.empty();

  @override
  Stream<Duration?> get durationStream => const Stream<Duration?>.empty();

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(StoryFragment fragment, {String? preparedPath}) async {}

  @override
  Future<void> replay() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async {}
}

class _ControllableNarrationPlayer implements NarrationPlayer {
  final _completed = StreamController<bool>.broadcast(sync: true);
  final _playing = StreamController<bool>.broadcast(sync: true);
  final playedFragmentIds = <String>[];

  void completeNaturally() => _completed.add(true);

  @override
  Stream<bool> get completedStream => _completed.stream;

  @override
  Stream<Duration?> get durationStream => const Stream<Duration?>.empty();

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Future<void> dispose() async {
    await _completed.close();
    await _playing.close();
  }

  @override
  Future<void> pause() async => _playing.add(false);

  @override
  Future<void> play(StoryFragment fragment, {String? preparedPath}) async {
    playedFragmentIds.add(fragment.id);
    _playing.add(true);
  }

  @override
  Future<void> replay() async => _playing.add(true);

  @override
  Future<void> resume() async => _playing.add(true);

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> stop() async => _playing.add(false);
}
