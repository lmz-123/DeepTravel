import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/presentation/route_manual/chapter_directory.dart';
import 'package:jiandi/features/experience/presentation/route_manual/chapter_prelude.dart';
import 'package:jiandi/features/experience/presentation/route_manual/manual_chapter.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(360, 800)]) {
    testWidgets(
      'directory and prelude fit $size; selecting does not start listening',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: RouteChapterDirectory(
              chapters: _chapters(5),
              routeName: '武康路 · 安福路',
              visited: const {},
              currentId: 'chapter-1',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('翻到'), findsOneWidget);
        expect(find.byTooltip('下一页章节'), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('directory-chapter-chapter-2')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ChapterPrelude), findsOneWidget);
        expect(find.text('返回目录'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('manual-read-chapter')),
          findsOneWidget,
        );
        await tester.tap(find.text('返回目录'));
        await tester.pumpAndSettle();
        expect(find.byType(ChapterPrelude), findsNothing);
        expect(find.byType(RouteChapterDirectory), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    '137 chapters use 12 per page, original-number search, and preserved browse state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: RouteChapterDirectory(
            chapters: _chapters(137),
            routeName: '城市长目录',
            visited: const {'chapter-137'},
            currentId: 'chapter-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.childrenDelegate.estimatedChildCount, 12);
      await tester.tap(find.byTooltip('下一页章节'));
      await tester.pumpAndSettle();
      expect(find.text('第 13–24 项 / 137'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '137');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('directory-chapter-chapter-137')),
        findsOneWidget,
      );
      expect(find.byTooltip('下一页章节'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('directory-chapter-chapter-137')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('返回目录'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '137',
      );
      expect(
        find.byKey(const ValueKey('directory-chapter-chapter-137')),
        findsOneWidget,
      );
      await tester.tap(find.text('未翻阅'));
      await tester.pumpAndSettle();
      expect(find.text('这一页，\n暂时留白。'), findsOneWidget);
      await tester.tap(find.text('查看全部故事  →'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListView>(find.byType(ListView))
            .childrenDelegate
            .estimatedChildCount,
        12,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

List<ManualChapter> _chapters(int count) => List.generate(
  count,
  (index) => ManualChapter(
    id: 'chapter-${index + 1}',
    number: index + 1,
    title: '城市第 ${index + 1} 个故事',
    place: '第 ${index + 1} 处停留',
    body: '慢慢走，才看得见。这里是一篇安静的城市手册。',
    image: '',
  ),
);
