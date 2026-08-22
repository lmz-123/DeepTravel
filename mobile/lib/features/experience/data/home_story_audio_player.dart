import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/home_story.dart';

class HomeStoryAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _noisy;
  StreamSubscription<AudioInterruptionEvent>? _interruptions;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playerStateStream
      .map((state) =>
          state.playing && state.processingState != ProcessingState.completed)
      .distinct();
  Stream<bool> get completedStream => _player.playerStateStream
      .map((state) => state.processingState == ProcessingState.completed)
      .distinct();

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _noisy = session.becomingNoisyEventStream.listen((_) => _player.pause());
    _interruptions = session.interruptionEventStream.listen((event) {
      if (event.begin) _player.pause();
    });
  }

  Future<Duration?> prepare(HomeStory story) async {
    if (story.audioUrl.isEmpty) {
      throw StateError('故事音频尚未发布');
    }
    return _player.setAudioSource(
      AudioSource.uri(
        Uri.parse(story.audioUrl),
        tag: MediaItem(
          id: story.id,
          album: '见地 · 听一个短故事',
          title: story.title,
          artist: '${story.cityName} · ${story.narratorName}',
          artUri:
              story.coverImage.isEmpty ? null : Uri.tryParse(story.coverImage),
        ),
      ),
    );
  }

  Future<void> play() async {
    unawaited(_player.play().catchError((Object _, StackTrace __) {}));
  }

  Future<void> pause() => _player.pause();
  Future<void> seek(Duration value) => _player.seek(value);
  Future<void> replay() async {
    await _player.seek(Duration.zero);
    await play();
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() async {
    await _noisy?.cancel();
    await _interruptions?.cancel();
    await _player.dispose();
  }
}

final homeStoryAudioPlayerProvider = Provider<HomeStoryAudioPlayer>((ref) {
  final player = HomeStoryAudioPlayer();
  unawaited(player.initialize());
  ref.onDispose(player.dispose);
  return player;
});
