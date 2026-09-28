import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_page.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(360, 800)]) {
    testWidgets('editorial discovery fits ${size.width} and opens real route', (
      tester,
    ) async {
      await _pump(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('不赶路，'), findsOneWidget);
      expect(find.text('去听海。'), findsOneWidget);
      expect(find.text('随刊'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('route-card-route-0')));
      await tester.pumpAndSettle();
      expect(find.text('detail:route-0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'city index searches real metadata and restores selection after detail',
    (tester) async {
      await _pump(tester, tab: 'atlas');
      expect(find.text('城市索引.'), findsOneWidget);
      expect(find.text('收录 37 条路线'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '测试路线 36');
      await tester.pumpAndSettle();
      expect(find.text('找到 1 条路线'), findsOneWidget);
      final row = find.byKey(const ValueKey('atlas-route-route-36'));
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.text('测试路线 36')),
      );
      await tester.pumpAndSettle();
      expect(find.text('detail:route-36'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '测试路线 36'), findsOneWidget);
      expect(find.text('找到 1 条路线'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long route catalogue expands in bounded pages and filter draft can cancel',
    (tester) async {
      await _pump(tester, tab: 'atlas');
      final list = find.byType(CustomScrollView);
      await tester.scrollUntilVisible(
        find.text('再看 17 条路线'),
        600,
        scrollable:
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      await tester.tap(find.text('再看 17 条路线'));
      await tester.pumpAndSettle();
      expect(find.text('再看 17 条路线'), findsNothing);
      await tester.tap(find.text('区域 / 时长'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('45 分钟内'));
      await tester.tap(find.byTooltip('关闭筛选'));
      await tester.pumpAndSettle();
      await tester.fling(list, const Offset(0, 6000), 12000);
      await tester.pumpAndSettle();
      expect(find.text('收录 37 条路线'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty shelf is a deliberate state and directs back to journal', (
    tester,
  ) async {
    await _pump(tester, tab: 'shelf');
    expect(find.text('你的下一页，\n还没有写下。'), findsOneWidget);
    await tester.tap(find.text('去翻一翻'));
    await tester.pumpAndSettle();
    expect(find.text('不赶路，'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  String? tab,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: tab == null ? '/' : '/?tab=$tab',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) =>
            DiscoveryPage(initialTab: state.uri.queryParameters['tab']),
      ),
      GoRoute(
        path: '/route/:slug',
        builder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Text('detail:${state.pathParameters['slug']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(null),
        discoveryControllerProvider.overrideWith(_TestDiscovery.new),
        activeTourControllerProvider.overrideWith(_TestTour.new),
      ],
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestTour extends ActiveTourController {
  @override
  ActiveTourState build() => const ActiveTourState();
}

class _TestDiscovery extends DiscoveryController {
  @override
  Future<DiscoveryState> build() async {
    final routes = List.generate(
      37,
      (i) => RouteExperience(
        id: 'route-$i',
        slug: 'route-$i',
        title: i == 0 ? '测试海岸' : '测试路线 $i',
        subtitle: '街区 $i 的真实故事',
        description: '步行路线 $i',
        durationMinutes: i + 30,
        distanceKm: 1 + i / 10,
        difficulty: '轻松',
        theme: i.isEven ? '自然' : '街区',
        heroImage: '',
        contentStatus: 'published',
        stops: const [],
        isFeatured: i == 0,
      ),
    );
    return DiscoveryState(
      cities: const [_city],
      city: _city,
      catalog: CityDiscoveryCatalog(routes: routes),
      cards: routes.map((route) => ScenicAreaCard(route: route)).toList(),
      revision: 0,
    );
  }

  @override
  Future<DiscoveryStartupAction> prepareColdStart() async =>
      DiscoveryStartupAction.completed;
}

const _city = CityExperience(
  id: 'city',
  slug: 'test',
  name: '测试城',
  subtitle: '城市故事',
  heroImage: '',
);
