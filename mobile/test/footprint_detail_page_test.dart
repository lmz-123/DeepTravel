import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/footprint_models.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/footprint_detail_page.dart';

void main() {
  testWidgets('detail has three semantic sections and no audio or community',
      (tester) async {
    final repository = _FootprintRepository(_entry());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        experienceRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
          home: FootprintDetailPage(footprintId: 'footprint-1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('见地讲述'), findsOneWidget);
    expect(find.text('我看到的'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('我留下的'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('我留下的'), findsOneWidget);
    expect(find.text('拍一张私人留念'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('稍后再整理'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('稍后再整理'), findsOneWidget);
    expect(find.byIcon(Icons.headphones_rounded), findsNothing);
    expect(find.textContaining('回听'), findsNothing);
    expect(find.textContaining('社区'), findsNothing);
    expect(find.textContaining('播放进度'), findsNothing);
  });

  testWidgets('short personal record can be saved without a photo',
      (tester) async {
    final repository = _FootprintRepository(_entry());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        experienceRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
          home: FootprintDetailPage(footprintId: 'footprint-1')),
    ));
    await tester.pumpAndSettle();

    final observation = find.widgetWithText(TextField, '我看到的细节（可选）');
    await tester.scrollUntilVisible(observation, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(observation, '我看到一段颜色更浅的砖。');
    final sentence = find.widgetWithText(TextField, '我留下的一句话（可选）');
    await tester.scrollUntilVisible(sentence, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(sentence, '城市没有停在过去。');
    await tester.ensureVisible(find.text('保存足迹'));
    await tester.tap(find.text('保存足迹'));
    await tester.pumpAndSettle();

    expect(repository.saved?.observation, '我看到一段颜色更浅的砖。');
    expect(repository.saved?.sentence, '城市没有停在过去。');
    expect(find.text('足迹已经保存'), findsOneWidget);
  });
}

class _FootprintRepository extends DemoExperienceRepository {
  _FootprintRepository(this.entry) : super(latency: Duration.zero);
  FootprintEntry entry;
  FootprintDraft? saved;

  @override
  Future<FootprintEntry> footprint(String footprintId) async => entry;

  @override
  Future<FootprintEntry> updateFootprint(
      String footprintId, FootprintDraft draft) async {
    saved = draft;
    entry = FootprintEntry(
      id: entry.id,
      journeyId: entry.journeyId,
      cityId: entry.cityId,
      citySlug: entry.citySlug,
      cityName: entry.cityName,
      sceneId: entry.sceneId,
      sceneTitle: entry.sceneTitle,
      storyTitle: entry.storyTitle,
      editorialSummary: entry.editorialSummary,
      summaryOptions: entry.summaryOptions,
      themes: entry.themes,
      organizationState: draft.deferOrganization ? 'draft' : 'organized',
      journeyState: entry.journeyState,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt.add(const Duration(seconds: 1)),
      selectedSummaryId: draft.selectedSummaryId,
      selectedSummaryText: entry.summaryOptions.first.text,
      observation: draft.observation,
      sentence: draft.sentence,
    );
    return entry;
  }

  @override
  Future<List<RelatedCityContent>> footprintRelatedContent(
          String footprintId) async =>
      const [];
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
      journeyState: 'completed',
      createdAt: DateTime(2026, 8, 23),
      updatedAt: DateTime(2026, 8, 23),
    );
