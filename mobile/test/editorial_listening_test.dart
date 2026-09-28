import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/presentation/widgets/editorial_listening.dart';

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets(
      'V5 listening fits a $width point phone without starting audio',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var playCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: editorialInk,
              body: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width <= 375 ? 18 : 22,
                ),
                child: ListView(
                  children: [
                    EditorialFocusHeader(
                      onBack: () {},
                      onDirectory: () {},
                      showBackLabel: true,
                      backLabel: '路线介绍',
                    ),
                    const EditorialRecordArtwork(
                      imageUrl: '',
                      chapterNumber: 12,
                      isPlaying: false,
                    ),
                    const EditorialChapterHeading(
                      number: 12,
                      total: 137,
                      title: '一幢楼，盛得下半部上海史',
                      location: '武康大楼',
                    ),
                    EditorialPlaybackControls(
                      isPlaying: false,
                      position: Duration.zero,
                      duration: const Duration(minutes: 3),
                      onToggle: () => playCount++,
                      onSeek: (_) {},
                      chapterNavigation: true,
                      onNext: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(playCount, 0);
        expect(
          tester.getSize(find.byKey(const ValueKey('editorial-record'))).width,
          width <= 375 ? 185 : 207,
        );
        expect(tester.getSize(find.byTooltip('播放这一篇')), const Size(64, 64));
        await tester.ensureVisible(find.byTooltip('播放这一篇'));
        await tester.tap(find.byTooltip('播放这一篇'));
        expect(playCount, 1);
      },
    );
  }

  testWidgets('record moves only while playing and respects reduced motion', (
    tester,
  ) async {
    Widget page({required bool playing, bool reducedMotion = false}) =>
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Scaffold(
              body: EditorialRecordArtwork(
                imageUrl: '',
                chapterNumber: 1,
                isPlaying: playing,
              ),
            ),
          ),
        );
    await tester.pumpWidget(page(playing: true));
    await tester.pump(const Duration(seconds: 1));
    final rotation = tester.widget<RotationTransition>(
      find.descendant(
          of: find.byType(EditorialRecordArtwork),
          matching: find.byType(RotationTransition)),
    );
    expect(rotation.turns.value, closeTo(1 / 30, .001));
    await tester.pumpWidget(page(playing: false));
    final pausedValue = rotation.turns.value;
    await tester.pump(const Duration(seconds: 2));
    expect(rotation.turns.value, pausedValue);
    await tester.pumpWidget(page(playing: true, reducedMotion: true));
    await tester.pump(const Duration(seconds: 2));
    expect(rotation.turns.value, pausedValue);
    await tester.pumpAndSettle();
  });

  testWidgets('chapter navigation does not seek or implicitly play', (
    tester,
  ) async {
    var played = false;
    var selected = false;
    Duration? seek;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorialPlaybackControls(
            isPlaying: false,
            position: Duration.zero,
            duration: const Duration(minutes: 1),
            onToggle: () => played = true,
            onSeek: (value) => seek = value,
            chapterNavigation: true,
            onNext: () => selected = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('下一段'));
    expect(selected, isTrue);
    expect(played, isFalse);
    expect(seek, isNull);
    final previous = tester.widget<TextButton>(
      find.ancestor(of: find.text('上一段'), matching: find.byType(TextButton)),
    );
    expect(previous.onPressed, isNull);
  });
}
