import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AudioOwnerKind { none, route, story }

class AudioOwnershipState {
  const AudioOwnershipState({
    this.kind = AudioOwnerKind.none,
    this.destination = '/',
    this.title = '',
    this.subtitle = '',
    this.artwork = '',
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.generation = 0,
  });

  final AudioOwnerKind kind;
  final String destination;
  final String title;
  final String subtitle;
  final String artwork;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final int generation;

  bool get isActive => kind != AudioOwnerKind.none;

  AudioOwnershipState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) =>
      AudioOwnershipState(
        kind: kind,
        destination: destination,
        title: title,
        subtitle: subtitle,
        artwork: artwork,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        generation: generation,
      );
}

class AudioOwnershipController extends Notifier<AudioOwnershipState> {
  @override
  AudioOwnershipState build() => const AudioOwnershipState();

  int acquire({
    required AudioOwnerKind kind,
    required String destination,
    required String title,
    required String subtitle,
    required String artwork,
    Duration? duration,
  }) {
    final generation = state.generation + 1;
    state = AudioOwnershipState(
      kind: kind,
      destination: destination,
      title: title,
      subtitle: subtitle,
      artwork: artwork,
      duration: duration,
      generation: generation,
    );
    return generation;
  }

  void playing(int generation, bool value) {
    if (state.generation != generation) return;
    state = state.copyWith(isPlaying: value);
  }

  void progress(int generation, Duration position, Duration? duration) {
    if (state.generation != generation) return;
    state = state.copyWith(position: position, duration: duration);
  }

  void clear(int generation) {
    if (state.generation != generation) return;
    state = AudioOwnershipState(generation: generation + 1);
  }
}

final audioOwnershipProvider =
    NotifierProvider<AudioOwnershipController, AudioOwnershipState>(
  AudioOwnershipController.new,
);
