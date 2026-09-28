import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/home_story_audio_player.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/home_story.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/audio_ownership_controller.dart';
import 'package:jiandi/features/experience/presentation/home_story_controller.dart';

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
}

class _ManualPlayer implements HomeStoryAudioPlayer {
  int playCount = 0;
  int prepareCount = 0;
  Duration? seekPosition;
  Completer<Duration?>? preparation;
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
