import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_experience_repository.dart';
import '../data/home_story_audio_player.dart';
import '../domain/home_story.dart';
import 'active_tour_controller.dart';
import 'audio_ownership_controller.dart';
import 'experience_providers.dart';

enum HomeStoryPhase {
  idle,
  loading,
  ready,
  playing,
  paused,
  ended,
  empty,
  error
}

class HomeStoryPlaybackState {
  const HomeStoryPlaybackState({
    this.phase = HomeStoryPhase.idle,
    this.story,
    this.position = Duration.zero,
    this.duration,
    this.message,
    this.citySlug,
  });

  final HomeStoryPhase phase;
  final HomeStory? story;
  final Duration position;
  final Duration? duration;
  final String? message;
  final String? citySlug;

  bool get isPlaying => phase == HomeStoryPhase.playing;

  HomeStoryPlaybackState copyWith({
    HomeStoryPhase? phase,
    HomeStory? story,
    Duration? position,
    Duration? duration,
    String? message,
    bool clearMessage = false,
    String? citySlug,
  }) =>
      HomeStoryPlaybackState(
        phase: phase ?? this.phase,
        story: story ?? this.story,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        message: clearMessage ? null : message ?? this.message,
        citySlug: citySlug ?? this.citySlug,
      );
}

class HomeStoryPlaybackController extends Notifier<HomeStoryPlaybackState> {
  StreamSubscription<Duration>? _position;
  StreamSubscription<Duration?>? _duration;
  StreamSubscription<bool>? _playing;
  StreamSubscription<bool>? _completed;
  String? _preparedStoryId;
  int _generation = 0;
  int? _ownershipGeneration;

  HomeStoryAudioPlayer get _player => ref.read(homeStoryAudioPlayerProvider);

  @override
  HomeStoryPlaybackState build() {
    ref.onDispose(() {
      _generation += 1;
      unawaited(_cancelBindings());
    });
    return const HomeStoryPlaybackState();
  }

  Future<void> load({String? citySlug, bool excludeCurrent = false}) async {
    final generation = ++_generation;
    final previousId = excludeCurrent ? state.story?.id : null;
    await _player.stop();
    await _cancelBindings();
    final ownership = _ownershipGeneration;
    if (ownership != null) {
      ref.read(audioOwnershipProvider.notifier).clear(ownership);
      _ownershipGeneration = null;
    }
    state = HomeStoryPlaybackState(
      phase: HomeStoryPhase.loading,
      citySlug: citySlug,
    );
    try {
      final story =
          await ref.read(experienceRepositoryProvider).randomHomeStory(
                citySlug: citySlug,
                excludeId: previousId,
              );
      if (generation != _generation) return;
      state = HomeStoryPlaybackState(
        phase: HomeStoryPhase.ready,
        story: story,
        duration: story.duration,
        citySlug: citySlug,
      );
    } catch (error) {
      if (generation != _generation) return;
      final empty =
          error is ExperienceFailure && error.code == 'story_pool_empty';
      state = HomeStoryPlaybackState(
        phase: empty ? HomeStoryPhase.empty : HomeStoryPhase.error,
        message: empty ? '这座城市的短故事还在录音棚里，换座城市看看吧。' : '故事暂时没有加载出来，请稍后重试。',
        citySlug: citySlug,
      );
    }
  }

  Future<void> play() async {
    final story = state.story;
    if (story == null) return;
    final generation = ++_generation;
    try {
      await ref
          .read(activeTourControllerProvider.notifier)
          .pauseForExternalAudio();
      if (_preparedStoryId != story.id) {
        await _player.stop();
        final duration = await _player.prepare(story);
        if (generation != _generation) return;
        _preparedStoryId = story.id;
        state = state.copyWith(
          duration: duration ?? story.duration,
          position: Duration.zero,
        );
      }
      await _bind(generation);
      final token = ref.read(audioOwnershipProvider.notifier).acquire(
            kind: AudioOwnerKind.story,
            destination: '/story',
            title: story.title,
            subtitle: '${story.cityName} · ${story.routeTitle}',
            artwork: story.coverImage,
            duration: state.duration ?? story.duration,
          );
      _ownershipGeneration = token;
      await _player.play();
      if (generation != _generation) return;
      state = state.copyWith(phase: HomeStoryPhase.playing, clearMessage: true);
      ref.read(audioOwnershipProvider.notifier).playing(token, true);
    } catch (_) {
      if (generation != _generation) return;
      state = state.copyWith(
        phase: HomeStoryPhase.error,
        message: '这段音频暂时不能播放，文字稿仍然可以阅读。',
      );
    }
  }

  Future<void> toggle() async {
    if (state.phase == HomeStoryPhase.playing) {
      await _player.pause();
      state = state.copyWith(phase: HomeStoryPhase.paused);
      final token = _ownershipGeneration;
      if (token != null) {
        ref.read(audioOwnershipProvider.notifier).playing(token, false);
      }
      return;
    }
    if (state.phase == HomeStoryPhase.ended) {
      await replay();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration value) => _player.seek(value);

  Future<void> replay() async {
    final story = state.story;
    if (story == null) return;
    if (_preparedStoryId != story.id) return play();
    final token = ref.read(audioOwnershipProvider.notifier).acquire(
          kind: AudioOwnerKind.story,
          destination: '/story',
          title: story.title,
          subtitle: '${story.cityName} · ${story.routeTitle}',
          artwork: story.coverImage,
          duration: state.duration ?? story.duration,
        );
    _ownershipGeneration = token;
    await _player.replay();
    state = state.copyWith(
      phase: HomeStoryPhase.playing,
      position: Duration.zero,
      clearMessage: true,
    );
    ref.read(audioOwnershipProvider.notifier).playing(token, true);
  }

  Future<void> _bind(int generation) async {
    await _cancelBindings();
    _position = _player.positionStream.listen((value) {
      if (generation != _generation) return;
      state = state.copyWith(position: value);
      final token = _ownershipGeneration;
      if (token != null) {
        ref
            .read(audioOwnershipProvider.notifier)
            .progress(token, value, state.duration);
      }
    });
    _duration = _player.durationStream.listen((value) {
      if (generation != _generation || value == null) return;
      state = state.copyWith(duration: value);
    });
    _playing = _player.playingStream.listen((value) {
      if (generation != _generation) return;
      if (!value && state.phase == HomeStoryPhase.playing) {
        state = state.copyWith(phase: HomeStoryPhase.paused);
      }
      final token = _ownershipGeneration;
      if (token != null) {
        ref.read(audioOwnershipProvider.notifier).playing(token, value);
      }
    });
    _completed = _player.completedStream.where((value) => value).listen((_) {
      if (generation != _generation) return;
      state = state.copyWith(
        phase: HomeStoryPhase.ended,
        position: state.duration ?? state.position,
      );
      final token = _ownershipGeneration;
      if (token != null) {
        ref.read(audioOwnershipProvider.notifier).clear(token);
      }
      _ownershipGeneration = null;
    });
  }

  Future<void> _cancelBindings() async {
    await _position?.cancel();
    await _duration?.cancel();
    await _playing?.cancel();
    await _completed?.cancel();
    _position = null;
    _duration = null;
    _playing = null;
    _completed = null;
  }
}

final homeStoryPlaybackControllerProvider =
    NotifierProvider<HomeStoryPlaybackController, HomeStoryPlaybackState>(
  HomeStoryPlaybackController.new,
);
