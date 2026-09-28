import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_experience_repository.dart';
import '../data/home_story_audio_player.dart';
import '../domain/home_story.dart';
import '../domain/fragment_models.dart';
import '../domain/models.dart';
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
  error,
}

enum ListeningSource { cityStory, manualChapter }

class HomeStoryPlaybackState {
  const HomeStoryPlaybackState({
    this.phase = HomeStoryPhase.idle,
    this.story,
    this.position = Duration.zero,
    this.duration,
    this.message,
    this.citySlug,
    this.source = ListeningSource.cityStory,
  });

  final HomeStoryPhase phase;
  final HomeStory? story;
  final Duration position;
  final Duration? duration;
  final String? message;
  final String? citySlug;
  final ListeningSource source;

  bool get isPlaying => phase == HomeStoryPhase.playing;

  HomeStoryPlaybackState copyWith({
    HomeStoryPhase? phase,
    HomeStory? story,
    Duration? position,
    Duration? duration,
    String? message,
    bool clearMessage = false,
    String? citySlug,
    ListeningSource? source,
  }) =>
      HomeStoryPlaybackState(
        phase: phase ?? this.phase,
        story: story ?? this.story,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        message: clearMessage ? null : message ?? this.message,
        citySlug: citySlug ?? this.citySlug,
        source: source ?? this.source,
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
  Duration _resumePosition = Duration.zero;

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
    _resumePosition = Duration.zero;
    final previousId = excludeCurrent ? state.story?.id : null;
    await _player.stop();
    if (!ref.mounted || generation != _generation) return;
    await _cancelBindings();
    if (!ref.mounted || generation != _generation) return;
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
      final story = await ref
          .read(experienceRepositoryProvider)
          .randomHomeStory(citySlug: citySlug, excludeId: previousId);
      if (!ref.mounted || generation != _generation) return;
      state = HomeStoryPlaybackState(
        phase: HomeStoryPhase.ready,
        story: story,
        duration: story.duration,
        citySlug: citySlug,
        source: ListeningSource.cityStory,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      final empty =
          error is ExperienceFailure && error.code == 'story_pool_empty';
      state = HomeStoryPlaybackState(
        phase: empty ? HomeStoryPhase.empty : HomeStoryPhase.error,
        message: empty ? '这座城市的短故事还在录音棚里，换座城市看看吧。' : '故事暂时没有加载出来，请稍后重试。',
        citySlug: citySlug,
      );
    }
  }

  Future<void> loadCatalog(String catalogId) async {
    _resumePosition = Duration.zero;
    final generation = ++_generation;
    await _player.stop();
    if (!ref.mounted || generation != _generation) return;
    await _cancelBindings();
    if (!ref.mounted || generation != _generation) return;
    final ownership = _ownershipGeneration;
    if (ownership != null) {
      ref.read(audioOwnershipProvider.notifier).clear(ownership);
      _ownershipGeneration = null;
    }
    state = const HomeStoryPlaybackState(phase: HomeStoryPhase.loading);
    try {
      final story =
          await ref.read(experienceRepositoryProvider).cityStory(catalogId);
      if (!ref.mounted || generation != _generation) return;
      state = HomeStoryPlaybackState(
        phase: HomeStoryPhase.ready,
        story: story,
        duration: story.duration,
        citySlug: story.citySlug,
        source: ListeningSource.cityStory,
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      state = const HomeStoryPlaybackState(
        phase: HomeStoryPhase.error,
        message: '故事暂时没有加载出来，请稍后重试。',
      );
    }
  }

  /// Prepare a public chapter without arriving at a location or starting GPS.
  Future<void> loadManualChapter(
    RouteExperience route,
    StoryFragment fragment, {
    required String coverImage,
    String place = '',
    Duration resumePosition = Duration.zero,
    String? preparedPath,
  }) async {
    final id =
        'manual:${route.id}:${fragment.id}:${fragment.audio.scriptVersion}';
    final audioUrl = preparedPath == null
        ? fragment.audio.url
        : Uri.file(preparedPath).toString();
    if (state.story?.id == id &&
        state.source == ListeningSource.manualChapter &&
        state.story?.audioUrl == audioUrl) {
      await pause();
      return;
    }
    final generation = ++_generation;
    await _player.stop();
    if (!ref.mounted || generation != _generation) return;
    await _cancelBindings();
    if (!ref.mounted || generation != _generation) return;
    final ownership = _ownershipGeneration;
    if (ownership != null) {
      ref.read(audioOwnershipProvider.notifier).clear(ownership);
    }
    _ownershipGeneration = null;
    _preparedStoryId = null;
    _resumePosition = resumePosition;
    final story = HomeStory(
      id: id,
      arcId: route.id,
      title: fragment.title ?? fragment.safePreview,
      introduction: fragment.safePreview,
      coverImage: coverImage,
      duration: Duration(seconds: fragment.expectedDurationSeconds ?? 0),
      transcript: fragment.transcript ?? fragment.safePreview,
      audioUrl: audioUrl,
      cityName: '',
      citySlug: '',
      routeTitle: route.title,
      routeSlug: route.slug,
      narratorName: route.audioTour
              ?.profile(route.audioTour?.defaultNarrationProfileId)
              ?.name ??
          '见地讲述者',
      contentType: '城市手册',
      placeContext: place,
    );
    state = HomeStoryPlaybackState(
      phase: HomeStoryPhase.ready,
      story: story,
      duration: story.duration,
      position: resumePosition,
      source: ListeningSource.manualChapter,
    );
  }

  Future<void> pause() async {
    if (!ref.mounted || state.story == null) return;
    final generation = ++_generation;
    await _player.pause();
    if (!ref.mounted || generation != _generation) return;
    await _cancelBindings();
    if (!ref.mounted || generation != _generation || state.story == null) {
      return;
    }
    state = state.copyWith(phase: HomeStoryPhase.paused);
    final token = _ownershipGeneration;
    if (token != null) {
      ref.read(audioOwnershipProvider.notifier).playing(token, false);
    }
  }

  AudioOwnerKind get _ownerKind => switch (state.source) {
        ListeningSource.manualChapter => AudioOwnerKind.manualChapter,
        ListeningSource.cityStory => AudioOwnerKind.cityStory,
      };

  String _destination(HomeStory story) =>
      state.source == ListeningSource.cityStory
          ? '/story/${story.id}'
          : '/route/${story.routeSlug}';

  bool _requestIsCurrent(int generation, String storyId) =>
      ref.mounted && generation == _generation && state.story?.id == storyId;

  Future<void> play() async {
    if (!ref.mounted) return;
    final story = state.story;
    if (story == null) return;
    final generation = ++_generation;
    try {
      await ref
          .read(activeTourControllerProvider.notifier)
          .pauseForExternalAudio();
      if (!_requestIsCurrent(generation, story.id)) return;
      if (_preparedStoryId != story.id) {
        await _player.stop();
        if (!_requestIsCurrent(generation, story.id)) return;
        final duration = await _player.prepare(story);
        if (!_requestIsCurrent(generation, story.id)) return;
        _preparedStoryId = story.id;
        final total = duration ?? story.duration;
        final resume = total > Duration.zero && _resumePosition >= total
            ? Duration.zero
            : _resumePosition;
        await _player.seek(resume);
        if (!_requestIsCurrent(generation, story.id)) return;
        _resumePosition = Duration.zero;
        state = state.copyWith(duration: total, position: resume);
      }
      await _bind(generation);
      if (!_requestIsCurrent(generation, story.id)) return;
      final token = ref.read(audioOwnershipProvider.notifier).acquire(
            kind: _ownerKind,
            destination: _destination(story),
            title: story.title,
            subtitle: '${story.cityName} · ${story.routeTitle}',
            artwork: story.coverImage,
            duration: state.duration ?? story.duration,
          );
      _ownershipGeneration = token;
      await _player.play();
      if (!_requestIsCurrent(generation, story.id)) return;
      state = state.copyWith(phase: HomeStoryPhase.playing, clearMessage: true);
      ref.read(audioOwnershipProvider.notifier).playing(token, true);
    } catch (_) {
      if (!_requestIsCurrent(generation, story.id)) return;
      state = state.copyWith(
        phase: HomeStoryPhase.error,
        message: '这段音频暂时不能播放，文字稿仍然可以阅读。',
      );
    }
  }

  Future<void> toggle() async {
    if (state.phase == HomeStoryPhase.playing) {
      await pause();
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
    if (!ref.mounted) return;
    final story = state.story;
    if (story == null) return;
    if (_preparedStoryId != story.id) return play();
    final generation = ++_generation;
    await _player.seek(Duration.zero);
    if (!_requestIsCurrent(generation, story.id)) return;
    state = state.copyWith(position: Duration.zero, clearMessage: true);
    // Use the same ownership and on-site audio handoff as every explicit play.
    await play();
  }

  Future<void> _bind(int generation) async {
    await _cancelBindings();
    if (!ref.mounted || generation != _generation) return;
    _position = _player.positionStream.listen((value) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(position: value);
      final token = _ownershipGeneration;
      if (token != null) {
        ref
            .read(audioOwnershipProvider.notifier)
            .progress(token, value, state.duration);
      }
    });
    _duration = _player.durationStream.listen((value) {
      if (!ref.mounted || generation != _generation || value == null) return;
      state = state.copyWith(duration: value);
    });
    _playing = _player.playingStream.listen((value) {
      if (!ref.mounted || generation != _generation) return;
      if (!value && state.phase == HomeStoryPhase.playing) {
        state = state.copyWith(phase: HomeStoryPhase.paused);
      }
      final token = _ownershipGeneration;
      if (token != null) {
        ref.read(audioOwnershipProvider.notifier).playing(token, value);
      }
    });
    _completed = _player.completedStream.where((value) => value).listen((_) {
      if (!ref.mounted || generation != _generation) return;
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
    final bindings = [_position, _duration, _playing, _completed];
    _position = null;
    _duration = null;
    _playing = null;
    _completed = null;
    await Future.wait(bindings
        .whereType<StreamSubscription>()
        .map((binding) => binding.cancel()));
  }

  Future<void> clearForAccountExit() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    _resumePosition = Duration.zero;
    await _player.stop();
    if (!ref.mounted || generation != _generation) return;
    await _cancelBindings();
    if (!ref.mounted || generation != _generation) return;
    final ownership = _ownershipGeneration;
    if (ownership != null) {
      ref.read(audioOwnershipProvider.notifier).clear(ownership);
    }
    _ownershipGeneration = null;
    _preparedStoryId = null;
    _resumePosition = Duration.zero;
    state = const HomeStoryPlaybackState();
  }
}

final homeStoryPlaybackControllerProvider =
    NotifierProvider<HomeStoryPlaybackController, HomeStoryPlaybackState>(
  HomeStoryPlaybackController.new,
);
