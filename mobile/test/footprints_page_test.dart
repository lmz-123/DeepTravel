import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/core/router/route_back.dart';
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
    expect(find.textContaining('只听了部分故事'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('partially completed journey remains visible and resumable',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentJourneyLibraryProvider.overrideWith(
          (ref) async => [_item('active', '还在行走', completed: false)],
        ),
      ],
      child: const MaterialApp(home: FootprintsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('还在行走'), findsOneWidget);
    expect(find.text('进行中'), findsNWidgets(2));
    expect(find.text('继续自由漫游'), findsOneWidget);
    expect(find.textContaining('3/5 条线索'), findsOneWidget);
  });

  testWidgets('system back returns footprint list home and detail to list',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/footprints',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('发现首页')),
        ),
        GoRoute(
          path: '/footprints',
          builder: (_, __) => const FootprintsPage(),
        ),
        GoRoute(
          path: '/footprints/:id',
          builder: (context, __) => RouteBackScope(
            fallbackLocation: '/footprints',
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: '返回足迹',
                  onPressed: () => popOrGo(context, '/footprints'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              body: const Text('足迹详情已打开'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentJourneyLibraryProvider.overrideWith(
          (ref) async => [_item('recent', '最近完成')],
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');

    router.go('/footprints');
    await tester.pumpAndSettle();
    await tester.tap(find.ancestor(
      of: find.text('最近完成'),
      matching: find.byType(InkWell),
    ));
    await tester.pumpAndSettle();
    expect(find.text('足迹详情已打开'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('最近完成'), findsOneWidget);
    expect(find.text('足迹详情已打开'), findsNothing);
  });
}

JourneyLibraryItem _item(
  String id,
  String title, {
  bool archived = false,
  bool completed = true,
  int evidence = 0,
}) =>
    JourneyLibraryItem(
      journey: JourneySession(
        id: '$id-journey',
        routeId: '$id-route',
        status: completed ? 'completed' : 'active',
        currentStopPosition: completed ? 5 : 3,
        arrivedStopId: null,
        answeredStopIds: const {},
        progress: completed ? 1 : .6,
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
      collectedCount: completed ? 5 : 3,
      totalCount: 5,
      evidenceCount: evidence,
    );
