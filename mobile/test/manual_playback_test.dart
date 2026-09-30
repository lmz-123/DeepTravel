import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/core/logging/runtime_log_reporter.dart';
import 'package:jiandi/features/experience/data/home_story_audio_player.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/home_story.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/audio_ownership_controller.dart';
import 'package:jiandi/features/experience/presentation/home_story_controller.dart';
import 'package:jiandi/features/experience/presentation/route_manual/manual_chapter.dart';

void main() {
  test(
      'manual chapter is quiet until explicit play, resumes, and owns the route destination',
      () async {
    final player = _ManualPlayer();
    final field = _FieldController();
    final container = ProviderContainer(
      overrides: [
        homeStoryAudioPlayerProvider.overrideWithValue(player),
        activeTourControllerProvider.overrideWith(() => field),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      homeStoryPlaybackControllerProvider.notifier,
    );
    await controller.loadManualChapter(
      _route,
      _chapter,
      coverImage: _route.heroImage,
      resumePosition: const Duration(seconds: 19),
    );
    expect(player.playCount, 0);
    expect(player.prepareCount, 0);
    expect(field.pauses, 0);
    await controller.play();
    expect(player.playCount, 1);
    expect(player.seekPosition, const Duration(seconds: 19));
    expect(field.pauses, 1);
    final owner = container.read(audioOwnershipProvider);
    expect(owner.kind, AudioOwnerKind.manualChapter);
    expect(owner.destination, '/route/quiet-route');
    expect(
      container.read(homeStoryPlaybackControllerProvider).isPlaying,
      isTrue,
    );
    await controller.pause();
    expect(
      container.read(homeStoryPlaybackControllerProvider).isPlaying,
      isFalse,
    );
    await controller.play();
    expect(player.prepareCount, 1);
    expect(player.playCount, 2);
    await controller.clearForAccountExit();
    expect(container.read(audioOwnershipProvider).isActive, isFalse);
    expect(container.read(homeStoryPlaybackControllerProvider).story, isNull);
  });

  test(
      'returning to directory cancels an already prepared resume during field handoff',
      () async {
    final player = _ManualPlayer();
    final field = _FieldController();
    final container = ProviderContainer(overrides: [
      homeStoryAudioPlayerProvider.overrideWithValue(player),
      activeTourControllerProvider.overrideWith(() => field),
    ]);
    addTearDown(container.dispose);
    final controller =
        container.read(homeStoryPlaybackControllerProvider.notifier);
    await controller.loadManualChapter(_route, _chapter,
        coverImage: _route.heroImage);
    await controller.play();
    await controller.pause();
    field.pauseGate = Completer<void>();
    final pending = controller.play();
    await Future<void>.delayed(Duration.zero);
    await controller.pause();
    field.pauseGate!.complete();
    await pending;
    expect(player.playCount, 1);
    expect(
        container.read(homeStoryPlaybackControllerProvider).isPlaying, isFalse);
  });

  test('leaving during preparation cancels pending play', () async {
    final player = _ManualPlayer()..preparation = Completer<Duration?>();
    final container = ProviderContainer(
      overrides: [
        homeStoryAudioPlayerProvider.overrideWithValue(player),
        activeTourControllerProvider.overrideWith(_FieldController.new),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      homeStoryPlaybackControllerProvider.notifier,
    );
    await controller.loadManualChapter(
      _route,
      _chapter,
      coverImage: _route.heroImage,
    );
    final pending = controller.play();
    await Future<void>.delayed(Duration.zero);
    await controller.pause();
    player.preparation!.complete(const Duration(minutes: 2));
    await pending;
    expect(player.playCount, 0);
    expect(
      container.read(homeStoryPlaybackControllerProvider).isPlaying,
      isFalse,
    );
  });

  test('manual directory and playback use the published default voice',
      () async {
    final route = _voicedRoute();
    final player = _ManualPlayer();
    final container = _container(player);
    final chapters = routeManualChapters(route);
    expect(chapters.single.fragment!.audio.url, _voiceAudio.url);
    expect(_voicedChapter.audio.url, _chapter.audio.url);

    final controller =
        container.read(homeStoryPlaybackControllerProvider.notifier);
    await controller.loadManualChapter(route, _voicedChapter, coverImage: '');
    await controller.play();
    expect(player.preparedStory?.audioUrl, _voiceAudio.url);
    expect(player.preparedStory?.narratorName, '温柔同行者');
    expect(player.preparedStory?.id, endsWith(':v2'));
  });

  test('removed default voice uses the available published profile', () async {
    final player = _ManualPlayer();
    final container = _container(player);
    await container
        .read(homeStoryPlaybackControllerProvider.notifier)
        .loadManualChapter(
            _voicedRoute(defaultProfile: 'removed'), _voicedChapter,
            coverImage: '');
    expect(container.read(homeStoryPlaybackControllerProvider).story?.audioUrl,
        _voiceAudio.url);
  });

  test(
      'prepared default voice uses the download cache key and valid local file',
      () async {
    final directory = await Directory.systemTemp.createTemp('manual-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        await File('${directory.path}/voice.mp3').writeAsBytes([1, 2, 3]);
    final store = _CacheStore(file.path, _voiceAudio.url, 'warm:v2', 3);
    final route = _voicedRoute();
    final cached =
        await preparedManualChapterPath(store, route, _voicedChapter);
    expect(cached, file.path);
    expect(store.requestedVersion, 'warm:v2');

    final player = _ManualPlayer();
    final container = _container(player);
    final controller =
        container.read(homeStoryPlaybackControllerProvider.notifier);
    await controller.loadManualChapter(route, _voicedChapter,
        coverImage: '', preparedPath: cached);
    await controller.play();
    expect(player.preparedStory?.audioUrl, Uri.file(file.path).toString());
  });

  test('missing or incomplete cache falls back to published online voice',
      () async {
    final directory = await Directory.systemTemp.createTemp('manual-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/voice.mp3').writeAsBytes([1]);
    final store = _CacheStore(file.path, _voiceAudio.url, 'warm:v2', 3);
    final route = _voicedRoute();
    expect(
        await preparedManualChapterPath(store, route, _voicedChapter), isNull);
    await file.delete();
    expect(
        await preparedManualChapterPath(store, route, _voicedChapter), isNull);

    final player = _ManualPlayer();
    final container = _container(player);
    final controller =
        container.read(homeStoryPlaybackControllerProvider.notifier);
    await controller.loadManualChapter(route, _voicedChapter,
        coverImage: '', preparedPath: file.path);
    await controller.play();
    expect(player.preparedStory?.audioUrl, _voiceAudio.url);
  });

  test('legacy default audio shares the default prefixed download cache key',
      () async {
    final directory = await Directory.systemTemp.createTemp('manual-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/voice.m4a').writeAsBytes([1]);
    final store = _CacheStore(file.path, _chapter.audio.url, 'default:v1', 1);
    expect(await preparedManualChapterPath(store, _route, _chapter), file.path);
  });

  test('playback failure reports source and host without signed URL or body',
      () async {
    final player = _ManualPlayer()
      ..prepareError = StateError('failed URL ${_voiceAudio.url}');
    final reporter = _AudioReporter();
    final container = _container(player, reporter: reporter);
    final controller =
        container.read(homeStoryPlaybackControllerProvider.notifier);
    await controller.loadManualChapter(_voicedRoute(), _voicedChapter,
        coverImage: '');
    await controller.play();
    expect(container.read(homeStoryPlaybackControllerProvider).phase,
        HomeStoryPhase.error);
    expect(reporter.message, 'story_playback_failed');
    expect(reporter.context['source'], 'manualChapter');
    expect(reporter.context['audio_host'], 'cdn.example.test');
    expect(reporter.context['audio_scheme'], 'https');
    expect(reporter.context.toString(), isNot(contains('Signature')));
    expect(reporter.context.toString(), isNot(contains('must-not-log')));
    expect(reporter.context.toString(), isNot(contains('published.mp3')));
    expect(reporter.stack, isNull);
  });
}

ProviderContainer _container(_ManualPlayer player, {_AudioReporter? reporter}) {
  final container = ProviderContainer(overrides: [
    homeStoryAudioPlayerProvider.overrideWithValue(player),
    activeTourControllerProvider.overrideWith(_FieldController.new),
    runtimeLogReporterProvider.overrideWithValue(reporter),
  ]);
  addTearDown(container.dispose);
  return container;
}

class _CacheStore implements TourStore {
  _CacheStore(this.path, this.url, this.version, this.size);
  final String path, url, version;
  final int size;
  String? requestedVersion;
  @override
  Future<String?> preparedAsset(
      String url, String version, int sizeBytes) async {
    requestedVersion = version;
    return this.url == url && this.version == version && size == sizeBytes
        ? path
        : null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AudioReporter implements RuntimeLogReporter {
  String? message;
  Map<String, Object?> context = {};
  StackTrace? stack;
  @override
  Future<void> error(String category, String message,
      {Object? error,
      StackTrace? stackTrace,
      Map<String, Object?> context = const {}}) async {
    this.message = message;
    this.context = context;
    stack = stackTrace;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ManualPlayer implements HomeStoryAudioPlayer {
  int playCount = 0;
  int prepareCount = 0;
  Duration? seekPosition;
  Completer<Duration?>? preparation;
  HomeStory? preparedStory;
  Object? prepareError;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<bool> get completedStream => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<Duration?> prepare(HomeStory story) async {
    prepareCount++;
    preparedStory = story;
    if (prepareError != null) throw prepareError!;
    return preparation == null
        ? const Duration(minutes: 2)
        : preparation!.future;
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration value) async {
    seekPosition = value;
  }

  @override
  Future<void> replay() async {
    await seek(Duration.zero);
    await play();
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _FieldController extends ActiveTourController {
  int pauses = 0;
  Completer<void>? pauseGate;
  @override
  ActiveTourState build() => const ActiveTourState();
  @override
  Future<void> pauseForExternalAudio() async {
    pauses++;
    if (pauseGate != null) await pauseGate!.future;
  }
}

const _chapter = StoryFragment(
  id: 'chapter-a',
  position: 1,
  safePreview: '沿途的故事',
  title: '一页城市',
  transcript: '这是公开手册的完整文字。',
  interactionType: 'passive',
  reviewState: 'reviewed',
  expectedDurationSeconds: 120,
  triggerRegion: TriggerRegion(
    latitude: 22.5,
    longitude: 114,
    entryRadiusM: 50,
    exitRadiusM: 80,
    maxAccuracyM: 35,
    qualifyingSamples: 2,
    sampleWindowSeconds: 15,
    cooldownSeconds: 120,
    auditState: 'reviewed',
  ),
  audio: NarrationAsset(
    url: 'https://original-bucket.example/unchanged/audio.m4a',
    mimeType: 'audio/mp4',
    sizeBytes: 1,
    scriptVersion: 'v1',
  ),
);
const _route = RouteExperience(
  id: 'route-a',
  slug: 'quiet-route',
  title: '城市手册',
  subtitle: '慢慢走',
  description: '把城市展开。',
  durationMinutes: 20,
  distanceKm: 1.2,
  difficulty: '轻松',
  theme: '历史',
  heroImage: 'https://original-bucket.example/unchanged/cover.jpg',
  contentStatus: 'published',
  stops: [],
  manualChapters: [_chapter],
);

const _voiceAudio = NarrationAsset(
  url: 'https://cdn.example.test/published.mp3?Signature=must-not-log#private',
  mimeType: 'audio/mpeg',
  sizeBytes: 3,
  scriptVersion: 'v2',
);

final _voicedChapter = StoryFragment(
  id: _chapter.id,
  position: _chapter.position,
  safePreview: _chapter.safePreview,
  title: _chapter.title,
  transcript: _chapter.transcript,
  interactionType: _chapter.interactionType,
  reviewState: _chapter.reviewState,
  triggerRegion: _chapter.triggerRegion,
  audio: _chapter.audio,
  narrationTracks: const {
    'warm': NarrationTrack(audio: _voiceAudio, transcriptHash: 'transcript'),
  },
);

RouteExperience _voicedRoute({String defaultProfile = 'warm'}) =>
    RouteExperience(
      id: _route.id,
      slug: _route.slug,
      title: _route.title,
      subtitle: _route.subtitle,
      description: _route.description,
      durationMinutes: _route.durationMinutes,
      distanceKm: _route.distanceKm,
      difficulty: _route.difficulty,
      theme: _route.theme,
      heroImage: _route.heroImage,
      contentStatus: _route.contentStatus,
      stops: const [],
      manualChapters: [_voicedChapter],
      audioTour: AudioTourManifest(
        title: '',
        centralQuestion: '',
        scriptVersion: 'v2',
        reviewState: 'reviewed',
        fieldAuditState: 'reviewed',
        productionReady: true,
        demoLabel: null,
        contentMethod: 'field',
        downloadSizeBytes: 3,
        fragments: [_voicedChapter],
        defaultNarrationProfileId: defaultProfile,
        narrationProfiles: const [
          NarrationVoiceProfile(
              id: 'warm',
              slug: 'warm',
              name: '温柔同行者',
              description: '',
              isDefault: true)
        ],
      ),
    );
