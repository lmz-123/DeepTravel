import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/prepared_route_service.dart';
import 'package:jiandi/features/experience/data/home_story_audio_player.dart';
import 'package:jiandi/features/experience/domain/home_story.dart';
import 'package:jiandi/features/experience/presentation/home_story_controller.dart';
import 'package:jiandi/features/experience/presentation/audio_ownership_controller.dart';
import 'package:jiandi/features/experience/presentation/route_manual/manual_session.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/data/route_offline_package_service.dart';
import 'package:jiandi/features/experience/data/user_preferences_repository.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/experience_repository.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/location_mode_controller.dart';
import 'package:jiandi/features/experience/presentation/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'settings persist choices and clear only audio after confirmation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = UserPreferencesRepository();
    final location = _LocationStore();
    final cache = _CacheService();
    final offlineCache = _OfflineCacheService();
    final player = _Player();
    final storyPlayer = _StoryPlayer();
    addTearDown(storyPlayer.dispose);
    final tourStore = _Store();
    final repository = _ResetRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-a'),
        userPreferencesRepositoryProvider.overrideWithValue(preferences),
        locationModeStoreProvider.overrideWithValue(location),
        evidencePolicyProvider.overrideWith(
          (ref, userId) async => const EvidencePolicy(
            uploadEnabled: true,
            retentionDays: 30,
            maxBytes: 8388608,
            maxEdgePixels: 2048,
            allowedMimeTypes: ['image/jpeg'],
            privateAccess: true,
            exifRemoved: true,
            normalizedOnUpload: true,
          ),
        ),
        appVersionProvider.overrideWith((ref) async => '0.3.2+6'),
        preparedRouteServiceProvider.overrideWithValue(cache),
        routeOfflinePackageServiceProvider.overrideWithValue(offlineCache),
        narrationPlayerProvider.overrideWithValue(player),
        homeStoryAudioPlayerProvider.overrideWithValue(storyPlayer),
        tourStoreProvider.overrideWithValue(tourStore),
        experienceRepositoryProvider.overrideWithValue(repository),
        locationTrackerProvider.overrideWithValue(_Tracker()),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('保留 30 天'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('保留 30 天'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('见地版本'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('0.3.2+6'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('默认播放速度'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('默认播放速度'), findsOneWidget);
    await tester.tap(find.text('1.0×'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.25×').last);
    await tester.pumpAndSettle();
    expect(await preferences.readPlaybackSpeed('user-a'), 1.25);
    expect(player.speed, 1.25);

    await tester.ensureVisible(find.text('仅 Wi-Fi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅 Wi-Fi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动').last);
    await tester.pumpAndSettle();
    expect(
      await preferences.readDownloadPolicy('user-a'),
      DownloadPolicy.manual,
    );

    await tester.scrollUntilVisible(
      find.byType(Switch),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(location.mode, TourLocationMode.simulated);

    await tester.scrollUntilVisible(
      find.text('离线缓存'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('离线缓存'));
    await tester.pumpAndSettle();
    expect(find.text('测试景点'), findsOneWidget);
    expect(find.text('测试城 · 版本 v1 · 2 段音频'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('remove-offline-package-route-a')),
    );
    await tester.pumpAndSettle();
    expect(find.text('清除测试景点离线缓存？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();
    expect(offlineCache.removedSlug, 'route-a');
    expect(find.text('暂无离线景点包'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('清除已下载音频'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('清除已下载音频'));
    await tester.pumpAndSettle();
    expect(find.text('清除音频缓存？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '清除'));
    await tester.pumpAndSettle();
    expect(cache.clearCalls, 1);
    expect(find.textContaining('已清除 3 条音频缓存'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('清除探索记录'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final container =
        ProviderScope.containerOf(tester.element(find.byType(SettingsPage)));
    await container.read(manualSessionProvider('route-a').future);
    await container.read(manualSessionProvider('route-a').notifier).remember(
        'manual-chapter',
        opened: true,
        position: const Duration(seconds: 19));
    final readingBefore =
        await container.read(manualSessionProvider('route-a').future);
    expect(readingBefore.visited, {'manual-chapter'});
    expect(
        readingBefore.positions['manual-chapter'], const Duration(seconds: 19));
    final listening =
        container.read(homeStoryPlaybackControllerProvider.notifier);
    await listening.loadManualChapter(_installedPackage.route, _manualChapter,
        coverImage: '', resumePosition: const Duration(seconds: 19));
    await listening.play();
    expect(
        container.read(homeStoryPlaybackControllerProvider).isPlaying, isTrue);
    expect(container.read(audioOwnershipProvider).kind,
        AudioOwnerKind.manualChapter);
    final stopsBeforeReset = storyPlayer.stopCalls;
    await tester.tap(find.text('清除探索记录'));
    await tester.pumpAndSettle();
    expect(find.text('清除全部探索记录？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '确认清除'));
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.clearCalls, 1);
    expect(tourStore.clearCalls, 1);
    expect(storyPlayer.stopCalls, stopsBeforeReset + 1);
    expect(storyPlayer.playing, isFalse);
    expect(container.read(homeStoryPlaybackControllerProvider).story, isNull);
    expect(container.read(audioOwnershipProvider).isActive, isFalse);
    final readingAfter =
        await container.read(manualSessionProvider('route-a').future);
    expect(readingAfter.currentId, isNull);
    expect(readingAfter.visited, isEmpty);
    expect(readingAfter.positions, isEmpty);
    expect(tourStore.records, isEmpty);
    expect(find.textContaining('已重置 2 段旅程、10 个节点'), findsOneWidget);
  });
}

class _ResetRepository extends DemoExperienceRepository {
  _ResetRepository() : super(latency: Duration.zero);

  int clearCalls = 0;

  @override
  Future<ExplorationResetResult> clearExplorationProgress() async {
    clearCalls += 1;
    return const ExplorationResetResult(journeyCount: 2, fragmentCount: 10);
  }
}

class _OfflineCacheService extends RouteOfflinePackageService {
  _OfflineCacheService()
      : super(Dio(), _Store(), PreparedRouteService(Dio(), _Store()));

  String? removedSlug;

  @override
  Future<List<InstalledRoutePackage>> installedPackages() async =>
      removedSlug == null ? const [_installedPackage] : const [];

  @override
  Future<PreparedAudioClearResult> remove(String slug) async {
    removedSlug = slug;
    return const PreparedAudioClearResult(
      removedCount: 2,
      failedPaths: [],
    );
  }
}

const _installedPackage = InstalledRoutePackage(
  city: CityExperience(
    id: 'city-a',
    slug: 'city-a',
    name: '测试城',
    subtitle: '测试',
    heroImage: '',
  ),
  route: RouteExperience(
    id: 'route-a',
    slug: 'route-a',
    title: '测试景点',
    subtitle: '测试',
    description: '测试景点',
    durationMinutes: 20,
    distanceKm: 1.2,
    difficulty: '轻松',
    theme: '历史',
    heroImage: '',
    contentStatus: 'published',
    stops: [],
  ),
  version: 'v1',
  checksumSha256:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  narrationProfileId: null,
  preparedPaths: {
    'fragment-a': '/cache/a.m4a',
    'fragment-b': '/cache/b.m4a',
  },
  raw: {},
);

class _CacheService extends PreparedRouteService {
  _CacheService() : super(Dio(), _Store());

  int clearCalls = 0;

  @override
  Future<PreparedAudioClearResult> clearPreparedAudio() async {
    clearCalls += 1;
    return const PreparedAudioClearResult(removedCount: 3, failedPaths: []);
  }
}

class _LocationStore implements LocationModeStore {
  TourLocationMode mode = TourLocationMode.real;

  @override
  Future<TourLocationMode> read() async => mode;

  @override
  Future<void> write(TourLocationMode mode) async => this.mode = mode;
}

class _Player implements NarrationPlayer {
  double speed = 1;

  @override
  Stream<bool> get completedStream => const Stream.empty();

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Stream<bool> get playingStream => const Stream.empty();

  @override
  Stream<Duration> get positionStream => const Stream.empty();

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
  Future<void> setSpeed(double speed) async => this.speed = speed;

  @override
  Future<void> stop() async {}
}

class _Tracker implements LocationTracker {
  @override
  Future<TourLocationPermission> requestPermission() async =>
      TourLocationPermission.granted;

  @override
  Stream<LocationSample> samples() => const Stream.empty();

  @override
  Future<void> stop() async {}
}

class _Store implements TourStore {
  int clearCalls = 0;
  final records = <String, Map<String, dynamic>>{};

  @override
  Future<void> acknowledge(String id) async {}

  @override
  Future<void> clearPrivateData() async {
    clearCalls += 1;
    records.clear();
  }

  @override
  Future<void> enqueue(OutboxEvent event) async {}

  @override
  Future<List<OutboxEvent>> pending() async => const [];

  @override
  Future<String?> preparedAsset(
          String url, String version, int sizeBytes) async =>
      null;

  @override
  Future<List<PreparedAssetRecord>> preparedAssets() async => const [];

  @override
  Future<void> removePreparedAsset(String url) async {}

  @override
  Future<Map<String, dynamic>?> readJson(String key) async => records[key];

  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {
    records[key] = value;
  }

  @override
  Future<void> savePreparedAsset(
      String url, String path, String version, int sizeBytes) async {}
}

class _StoryPlayer extends Fake implements HomeStoryAudioPlayer {
  int stopCalls = 0;
  bool playing = false;
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration?>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  @override
  Stream<Duration> get positionStream => _positions.stream;
  @override
  Stream<Duration?> get durationStream => _durations.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<bool> get completedStream => _completed.stream;
  @override
  Future<Duration?> prepare(HomeStory story) async =>
      const Duration(minutes: 2);
  @override
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> stop() async {
    stopCalls++;
    playing = false;
  }

  @override
  Future<void> seek(Duration value) async {}
  @override
  Future<void> dispose() async {
    await _positions.close();
    await _durations.close();
    await _playing.close();
    await _completed.close();
  }
}

const _manualChapter = StoryFragment(
  id: 'manual-chapter',
  position: 1,
  safePreview: '测试章节',
  title: '测试章节',
  transcript: '测试手动听读内容',
  interactionType: 'passive',
  reviewState: 'reviewed',
  triggerRegion: TriggerRegion(
      latitude: 22.5,
      longitude: 114,
      entryRadiusM: 30,
      exitRadiusM: 50,
      maxAccuracyM: 20,
      qualifyingSamples: 2,
      sampleWindowSeconds: 15,
      cooldownSeconds: 120,
      auditState: 'reviewed'),
  audio: NarrationAsset(
      url: 'https://example.test/manual.m4a',
      mimeType: 'audio/mp4',
      sizeBytes: 10,
      scriptVersion: 'v1'),
);
