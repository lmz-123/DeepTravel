import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/domain/home_story.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/home_story_controller.dart';
import 'package:jiandi/features/experience/presentation/home_story_page.dart';

void main() {
  testWidgets('city story waits for play and switching to reading pauses it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final playback = _QuietStoryController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryControllerProvider.overrideWith(_EmptyDiscovery.new),
          homeStoryPlaybackControllerProvider.overrideWith(() => playback),
        ],
        child: const MaterialApp(home: HomeStoryPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(playback.toggleCount, 0);
    expect(find.text('街角的旧砖'), findsOneWidget);
    expect(find.text('完整故事正文，读到这里再抬头看看街角。'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('home-story-play-pause')),
    );
    await tester.tap(find.byKey(const ValueKey('home-story-play-pause')));
    await tester.pump();
    expect(playback.toggleCount, 1);
    expect(playback.isPlaying, isTrue);

    await tester.ensureVisible(find.text('安静地读这一篇'));
    await tester.tap(find.text('安静地读这一篇'));
    await tester.pumpAndSettle();
    expect(playback.toggleCount, 2);
    expect(playback.isPlaying, isFalse);
    expect(find.text('完整故事正文，读到这里再抬头看看街角。'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-story-play-pause')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _EmptyDiscovery extends DiscoveryController {
  @override
  Future<DiscoveryState> build() async => const DiscoveryState(
        cities: [],
        city: null,
        catalog: CityDiscoveryCatalog(routes: []),
        cards: [],
        revision: 0,
      );
}

class _QuietStoryController extends HomeStoryPlaybackController {
  int toggleCount = 0;
  bool get isPlaying => state.isPlaying;
  @override
  HomeStoryPlaybackState build() => const HomeStoryPlaybackState(
        phase: HomeStoryPhase.ready,
        story: HomeStory(
          id: 'story',
          arcId: 'arc',
          title: '街角的旧砖',
          introduction: '三分钟读懂街角',
          coverImage: '',
          duration: Duration(minutes: 3),
          transcript: '完整故事正文，读到这里再抬头看看街角。',
          audioUrl: '',
          cityName: '深圳',
          citySlug: 'shenzhen',
          routeTitle: '南头古城',
          routeSlug: 'nantou',
          narratorName: '见地',
        ),
      );
  @override
  Future<void> toggle() async {
    toggleCount++;
    state = state.copyWith(
      phase: state.isPlaying ? HomeStoryPhase.paused : HomeStoryPhase.playing,
    );
  }

  @override
  Future<void> pause() async {
    if (state.isPlaying) toggleCount++;
    state = state.copyWith(phase: HomeStoryPhase.paused);
  }

  @override
  Future<void> load({String? citySlug, bool excludeCurrent = false}) async {}
  @override
  Future<void> seek(Duration value) async {
    state = state.copyWith(position: value);
  }
}
