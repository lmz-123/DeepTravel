import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/footprints_page.dart';

void main() {
  testWidgets(
      'completed footprints show counts, backend order and archived items',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentJourneyLibraryProvider.overrideWith(
          (ref) async => [
            _item('recent', '最近完成', evidence: 2),
            _item('archived', '旧路线', archived: true),
          ],
        ),
      ],
      child: const MaterialApp(home: FootprintsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('10'), findsOneWidget);
    expect(find.text('2 张留念'), findsNothing);
    expect(find.textContaining('5/5 条线索 · 2 张照片'), findsOneWidget);
    expect(find.text('已归档'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('最近完成')).dy,
      lessThan(tester.getTopLeft(find.text('旧路线')).dy),
    );
  });

  testWidgets('empty footprint state stays neutral and refreshable',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentJourneyLibraryProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: FootprintsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('还没有留下足迹'), findsOneWidget);
    expect(find.textContaining('完整走完一条路线后'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
}

JourneyLibraryItem _item(
  String id,
  String title, {
  bool archived = false,
  int evidence = 0,
}) =>
    JourneyLibraryItem(
      journey: JourneySession(
        id: '$id-journey',
        routeId: '$id-route',
        status: 'completed',
        currentStopPosition: 5,
        arrivedStopId: null,
        answeredStopIds: const {},
        progress: 1,
      ),
      route: RouteExperience(
        id: '$id-route',
        slug: '$id-route',
        title: title,
        subtitle: '一条足迹',
        description: '测试',
        durationMinutes: 30,
        distanceKm: 1.2,
        difficulty: '轻松',
        theme: '城市',
        heroImage: '',
        contentStatus: archived ? 'archived' : 'published',
        stops: const [],
      ),
      journeyKind: 'fragmented',
      collectedCount: 5,
      totalCount: 5,
      evidenceCount: evidence,
    );
