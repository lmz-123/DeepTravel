import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/domain/footprint_models.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/footprints_page.dart';

void main() {
  testWidgets('footprints browse personal content without route statistics',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentFootprintsProvider.overrideWith((ref) async =>
            FootprintPageResult(items: [
              _entry()
            ], cities: const [
              FootprintCityFacet(slug: 'shenzhen', name: '深圳', count: 1)
            ], themes: const [
              FootprintThemeFacet(name: '城市历史', count: 1)
            ], months: const [
              FootprintTimeFacet(key: '2026-08', label: '2026年8月', count: 1)
            ], total: 1)),
      ],
      child: const MaterialApp(home: FootprintsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('我的足迹'), findsOneWidget);
    expect(find.text('深圳 · 南门城墙'), findsOneWidget);
    expect(find.text('漫游未完成'), findsOneWidget);
    expect(find.text('未完成漫游'), findsOneWidget);
    expect(find.textContaining('路线完成'), findsNothing);
    expect(find.textContaining('回听'), findsNothing);
    expect(find.textContaining('播放'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('深圳.*待整理.*无私人照片')),
      findsOneWidget,
    );
  });

  testWidgets('empty footprint state explains how records are created',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentFootprintsProvider.overrideWith((ref) async =>
            const FootprintPageResult(
                items: [], cities: [], themes: [], months: [], total: 0)),
      ],
      child: const MaterialApp(home: FootprintsPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('还没有留下足迹'), findsOneWidget);
    expect(find.textContaining('每听到一个故事'), findsOneWidget);
  });
}

FootprintEntry _entry() => FootprintEntry(
      id: 'footprint-1',
      journeyId: 'journey-1',
      cityId: 'city-1',
      citySlug: 'shenzhen',
      cityName: '深圳',
      sceneId: 'scene-1',
      sceneTitle: '南门城墙',
      storyTitle: '城墙留下的时间层次',
      editorialSummary: '新旧砖缝记录了城墙多次修缮，也让城市生活继续发生。',
      summaryOptions: const [
        FootprintSummaryOption(id: 'brick', text: '我留意到新旧砖缝的差别')
      ],
      themes: const ['城市历史'],
      organizationState: 'draft',
      journeyState: 'partial',
      createdAt: DateTime(2026, 8, 23),
      updatedAt: DateTime(2026, 8, 23),
    );
