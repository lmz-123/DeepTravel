import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:jiandi/features/experience/data/home_story_audio_player.dart';
import 'package:jiandi/features/experience/data/platform_tour_adapters.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/home_story.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/audio_ownership_controller.dart';
import 'package:jiandi/features/experience/presentation/home_story_controller.dart';

void main() {
  test('field playback cancels an in-flight manual preparation', () async {
    final manualPlayer = _DelayedManualPlayer();
    final fieldPlayer = _FieldPlayer();
    final container = ProviderContainer(overrides: [
      homeStoryAudioPlayerProvider.overrideWithValue(manualPlayer),
      narrationPlayerProvider.overrideWithValue(fieldPlayer),
      activeTourControllerProvider.overrideWith(_LoadedField.new),
    ]);
    addTearDown(container.dispose);
    final manual = container.read(homeStoryPlaybackControllerProvider.notifier);
    await manual.loadManualChapter(_route, _fragment, coverImage: '');
    final pending = manual.play();
    await manualPlayer.preparing.future;
    final field = container.read(activeTourControllerProvider.notifier);
    expect(await field.selectNode(_fragment.id), isTrue);
    manualPlayer.duration.complete(const Duration(minutes: 2));
    await pending;
    expect(manualPlayer.plays, 0);
    expect(fieldPlayer.plays, 1);
    expect(container.read(audioOwnershipProvider).kind, AudioOwnerKind.onSite);
    expect(container.read(activeTourControllerProvider).isPlaying, isTrue);
    expect(
        container.read(homeStoryPlaybackControllerProvider).isPlaying, isFalse);
  });

  test(
      'switching away while field source loads invalidates the delayed field play',
      () async {
    final raw = _AudioPlayerDouble();
    final fieldPlayer = JustAudioNarrationPlayer(player: raw);
    final container = ProviderContainer(overrides: [
      narrationPlayerProvider.overrideWithValue(fieldPlayer),
      activeTourControllerProvider.overrideWith(_LoadedField.new),
    ]);
    addTearDown(container.dispose);
    final field = container.read(activeTourControllerProvider.notifier);
    final pending = field.selectNode(_fragment.id);
    await raw.loading.future;
    await field.pauseForExternalAudio();
    raw.loadedDuration.complete(const Duration(minutes: 2));
    await pending;
    expect(raw.plays, 0);
    expect(container.read(activeTourControllerProvider).isPlaying, isFalse);
    // The same fragment can still be explicitly resumed after a cancelled load.
    raw.loadedDuration = Completer<Duration?>()
      ..complete(const Duration(minutes: 2));
    await field.togglePlayback();
    await Future<void>.delayed(Duration.zero);
    expect(raw.plays, 1);
    expect(container.read(activeTourControllerProvider).isPlaying, isTrue);
  });

  test(
      'native adapter stop cancels pending load and resume does not await audio completion',
      () async {
    final raw = _AudioPlayerDouble();
    final player = JustAudioNarrationPlayer(player: raw);
    final pending = player.play(_fragment);
    await raw.loading.future;
    await player.stop();
    raw.loadedDuration.complete(const Duration(minutes: 2));
    await pending;
    expect(raw.plays, 0);
    await player.resume().timeout(const Duration(seconds: 1));
    expect(raw.plays, 1);
    await player.replay().timeout(const Duration(seconds: 1));
    expect(raw.plays, 2);
  });
}

class _LoadedField extends ActiveTourController {
  @override
  ActiveTourState build() => const ActiveTourState(
        status: 'monitoring',
        route: _route,
        session: JourneySession(
            id: 'session',
            routeId: 'route',
            status: 'active',
            currentStopPosition: 1,
            arrivedStopId: null,
            answeredStopIds: {},
            progress: 0),
        ledger: StoryLedger(
            centralQuestion: '眼前的城',
            collectedCount: 0,
            totalCount: 1,
            reconstructionUnlocked: false,
            entries: [_fragment]),
      );
}

class _DelayedManualPlayer extends Fake implements HomeStoryAudioPlayer {
  final preparing = Completer<void>();
  final duration = Completer<Duration?>();
  int plays = 0;
  @override
  Future<Duration?> prepare(HomeStory story) {
    preparing.complete();
    return duration.future;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> play() async {
    plays++;
  }
}

class _FieldPlayer extends Fake implements NarrationPlayer {
  int plays = 0;
  @override
  Future<void> play(StoryFragment fragment, {String? preparedPath}) async {
    plays++;
  }

  @override
  Future<void> stop() async {}
  @override
  Stream<bool> get completedStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
}

class _AudioPlayerDouble extends Fake implements AudioPlayer {
  final loading = Completer<void>();
  Completer<Duration?> loadedDuration = Completer<Duration?>();
  final lifecycle = Completer<void>();
  int plays = 0;
  @override
  Future<Duration?> setAudioSource(AudioSource audioSource,
      {bool preload = true, int? initialIndex, Duration? initialPosition}) {
    if (!loading.isCompleted) loading.complete();
    return loadedDuration.future;
  }

  @override
  Future<void> play() {
    plays++;
    return lifecycle.future;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration? position, {int? index}) async {}
  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
}

const _fragment = StoryFragment(
    id: 'fragment',
    position: 1,
    safePreview: '街角的故事',
    title: '街角',
    transcript: '街角的文字',
    interactionType: 'passive',
    reviewState: 'reviewed',
    triggerRegion: TriggerRegion(
        latitude: 22.5,
        longitude: 114,
        entryRadiusM: 50,
        exitRadiusM: 80,
        maxAccuracyM: 35,
        qualifyingSamples: 2,
        sampleWindowSeconds: 15,
        cooldownSeconds: 120,
        auditState: 'reviewed'),
    audio: NarrationAsset(
        url: 'https://original.example/audio.m4a',
        mimeType: 'audio/mp4',
        sizeBytes: 1,
        scriptVersion: 'v1'));
const _route = RouteExperience(
    id: 'route',
    slug: 'route',
    title: '城市手册',
    subtitle: '慢慢走',
    description: '看看街角',
    durationMinutes: 20,
    distanceKm: 1.2,
    difficulty: '轻松',
    theme: '历史',
    heroImage: '',
    contentStatus: 'published',
    stops: [],
    audioTour: AudioTourManifest(
        title: '城市手册',
        centralQuestion: '眼前的城',
        scriptVersion: 'v1',
        reviewState: 'reviewed',
        fieldAuditState: 'reviewed',
        productionReady: true,
        demoLabel: null,
        contentMethod: 'research',
        downloadSizeBytes: 1,
        fragments: [_fragment]));
