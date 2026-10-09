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

  testWidgets('city map belongs to journal and returns to the same issue',
      (tester) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pumpAndSettle();
    final entry = find.bySemanticsLabel(RegExp('城市地图，查看景点与介绍'));
    await Scrollable.ensureVisible(tester.element(entry), alignment: .35);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('循着好奇，'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('返回随刊')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-card-shenzhen-mixc-world')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('journal includes all four Shenzhen routes with featured first', (
    tester,
  ) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    const order = [
      'nantou-time-layers',
      'shenzhen-mixc-world',
      'shenzhen-dameisha',
      'shenzhen-wutong-mountain',
    ];
    for (var i = 0; i < order.length; i++) {
      expect(find.text(' / 04'), findsOneWidget);
      expect(find.text('${i + 1}'.padLeft(2, '0')), findsOneWidget);
      expect(find.byKey(ValueKey('route-card-${order[i]}')), findsOneWidget);
      await tester.tap(find.byTooltip('下一期随刊'));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('route-card-nantou-time-layers')),
        findsOneWidget);
    await tester.tap(find.byTooltip('上一期随刊'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-card-shenzhen-wutong-mountain')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal without featured routes preserves every route and order',
      (
    tester,
  ) async {
    final routes = _shenzhenRoutes.where((route) => !route.isFeatured).toList();
    await _pump(tester, controller: _JournalDiscovery(routes));
    for (final route in routes) {
      expect(find.text(' / 03'), findsOneWidget);
      expect(find.byKey(ValueKey('route-card-${route.slug}')), findsOneWidget);
      await tester.drag(
        find.byWidgetPredicate((widget) =>
            widget is GestureDetector && widget.onHorizontalDragEnd != null),
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();
    }
    expect(find.byKey(ValueKey('route-card-${routes.first.slug}')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching cities resets the journal to its first issue', (
    tester,
  ) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pumpAndSettle();
    expect(find.text('02'), findsOneWidget);
    await tester.tap(find.byTooltip('选择城市'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('广州'));
    await tester.pumpAndSettle();
    expect(find.text('01'), findsOneWidget);
    expect(find.text(' / 02'), findsOneWidget);
    expect(find.byKey(const ValueKey('route-card-guangzhou-first')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal follows the finger and commits only after settling',
      (tester) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    final first = _routeCard('nantou-time-layers');
    final origin = tester.getTopLeft(first);
    final gesture = await tester.startGesture(tester.getCenter(_journalSwipe));
    await gesture.moveBy(const Offset(-24, 0));
    await gesture.moveBy(const Offset(-100, 0),
        timeStamp: const Duration(milliseconds: 120));
    await tester.pump();

    // The photograph moves below-left and rotates while the metadata barely
    // shifts. A whole-card slide would fail this composition contract.
    expect(tester.getTopLeft(first).dx,
        inExclusiveRange(origin.dx - 9, origin.dx));
    expect(tester.getTopLeft(first).dy,
        inExclusiveRange(origin.dy - 4, origin.dy));
    final photos = tester
        .widgetList<Transform>(find.byWidgetPredicate(
          (widget) =>
              widget is Transform &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>)
                  .value
                  .startsWith('journal-photo-'),
        ))
        .toList();
    expect(photos, hasLength(2));
    final departing = MatrixUtils.transformPoint(
        photos.first.transform, const Offset(220, 285));
    final arriving = MatrixUtils.transformPoint(
        photos.last.transform, const Offset(220, 285));
    expect(departing.dx, lessThan(210));
    expect(departing.dy, greaterThan(300));
    expect(arriving.dx, greaterThan(250));
    expect(arriving.dy, lessThan(270));
    expect(photos.first.transform.entry(1, 0), lessThan(0));
    expect(photos.last.transform.entry(1, 0), greaterThan(0));
    expect(find.text('01'), findsOneWidget);
    expect(_journalPages.evaluate().length, lessThanOrEqualTo(2));

    await gesture.up(timeStamp: const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('01'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('02'), findsOneWidget);
    expect(first, findsNothing);
    expect(_journalPages, findsOneWidget);
    final selected = _routeCard('shenzhen-mixc-world');
    expect(tester.getTopLeft(selected), origin);
    await tester.tap(selected);
    await tester.pumpAndSettle();
    expect(find.text('detail:shenzhen-mixc-world'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slow short swipe springs back without changing the issue',
      (tester) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    final first = _routeCard('nantou-time-layers');
    final origin = tester.getTopLeft(first);
    final gesture = await tester.startGesture(tester.getCenter(_journalSwipe));
    await gesture.moveBy(const Offset(-24, 0));
    await gesture.moveBy(const Offset(-28, 0),
        timeStamp: const Duration(milliseconds: 200));
    await tester.pump();
    expect(tester.getTopLeft(first).dx, lessThan(origin.dx));
    await gesture.moveBy(Offset.zero,
        timeStamp: const Duration(milliseconds: 600));
    await gesture.up(timeStamp: const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('01'), findsOneWidget);
    expect(tester.getTopLeft(first), origin);
    expect(_journalPages, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled journal drag restores the current issue',
      (tester) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    final first = _routeCard('nantou-time-layers');
    final origin = tester.getTopLeft(first);
    final gesture = await tester.startGesture(tester.getCenter(_journalSwipe));
    await gesture.moveBy(const Offset(-24, 0));
    await gesture.moveBy(const Offset(-150, 0),
        timeStamp: const Duration(milliseconds: 150));
    await tester.pump();
    expect(tester.getTopLeft(first).dx, lessThan(origin.dx));
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(find.text('01'), findsOneWidget);
    expect(tester.getTopLeft(first), origin);
    expect(_journalPages, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reversing a drag switches toward its final direction and wraps',
      (tester) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    final first = _routeCard('nantou-time-layers');
    final origin = tester.getTopLeft(first);
    final gesture = await tester.startGesture(tester.getCenter(_journalSwipe));
    await gesture.moveBy(const Offset(-24, 0));
    await gesture.moveBy(const Offset(-100, 0),
        timeStamp: const Duration(milliseconds: 100));
    await tester.pump();
    expect(tester.getTopLeft(first).dx, lessThan(origin.dx));
    await gesture.moveBy(const Offset(260, 0),
        timeStamp: const Duration(milliseconds: 400));
    await tester.pump();
    expect(tester.getTopLeft(first).dx, greaterThan(origin.dx));
    expect(_journalPages.evaluate().length, lessThanOrEqualTo(2));
    await gesture.up(timeStamp: const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('04'), findsOneWidget);
    expect(_routeCard('shenzhen-wutong-mountain'), findsOneWidget);
    expect(_journalPages, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a deliberate short fling advances the journal', (tester) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    await tester.fling(_journalSwipe, const Offset(-70, 0), 1400);
    await tester.pumpAndSettle();

    expect(find.text('02'), findsOneWidget);
    expect(_routeCard('shenzhen-mixc-world'), findsOneWidget);
    expect(_journalPages, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid arrow taps do not skip or reverse the active turn',
      (tester) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.tap(find.byTooltip('上一期随刊'));
    await tester.pumpAndSettle();

    expect(find.text('02'), findsOneWidget);
    expect(_routeCard('shenzhen-mixc-world'), findsOneWidget);
    expect(_journalPages, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taps and vertical drags do not cancel an arrow turn',
      (tester) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(_journalSwipe);
    await tester.pumpAndSettle();
    expect(find.text('02'), findsOneWidget);
    expect(_routeCard('shenzhen-mixc-world'), findsOneWidget);

    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final gesture = await tester.startGesture(tester.getCenter(_journalSwipe));
    await gesture.moveBy(const Offset(0, -48),
        timeStamp: const Duration(milliseconds: 120));
    await gesture.up(timeStamp: const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    expect(find.text('03'), findsOneWidget);
    expect(_routeCard('shenzhen-dameisha'), findsOneWidget);
    expect(_journalPages, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a horizontal drag can take over a turn, reverse it, or cancel',
      (tester) async {
    await _pump(tester, controller: _JournalDiscovery(_shenzhenRoutes));
    final first = _routeCard('nantou-time-layers');
    final origin = tester.getTopLeft(first);
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(first).dx, lessThan(origin.dx));

    final reverse = await tester.startGesture(tester.getCenter(_journalSwipe));
    await reverse.moveBy(const Offset(24, 0));
    await reverse.moveBy(const Offset(360, 0),
        timeStamp: const Duration(milliseconds: 500));
    await tester.pump();
    expect(tester.getTopLeft(first).dx, greaterThan(origin.dx));
    await reverse.up(timeStamp: const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('04'), findsOneWidget);
    expect(_routeCard('shenzhen-wutong-mountain'), findsOneWidget);

    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final cancel = await tester.startGesture(tester.getCenter(_journalSwipe));
    await cancel.moveBy(const Offset(-24, 0));
    await cancel.moveBy(const Offset(-40, 0),
        timeStamp: const Duration(milliseconds: 150));
    await tester.pump();
    await cancel.cancel();
    await tester.pumpAndSettle();

    expect(find.text('04'), findsOneWidget);
    expect(tester.getTopLeft(_routeCard('shenzhen-wutong-mountain')), origin);
    expect(_journalPages, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inventory changes cancel motion and preserve a surviving route',
      (tester) async {
    final controller = _JournalDiscovery(_shenzhenRoutes);
    await _pump(tester, controller: controller);
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pump(const Duration(milliseconds: 80));

    controller.replaceRoutes([
      _shenzhenRoutes.last,
      _shenzhenRoutes.first,
    ]);
    await tester.pumpAndSettle();
    expect(find.text(' / 02'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(_routeCard('shenzhen-mixc-world'), findsOneWidget);
    expect(_journalPages, findsOneWidget);

    controller.replaceRoutes([_shenzhenRoutes.last]);
    await tester.pumpAndSettle();
    expect(find.text('01'), findsOneWidget);
    expect(_routeCard('shenzhen-wutong-mountain'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing city or disposing during motion cancels its ticker',
      (tester) async {
    final controller = _JournalDiscovery(_shenzhenRoutes);
    await _pump(tester, controller: controller);
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pump(const Duration(milliseconds: 80));
    await controller.switchCity('guangzhou');
    await tester.pumpAndSettle();
    expect(find.text('01'), findsOneWidget);
    expect(_routeCard('guangzhou-first'), findsOneWidget);
    expect(_journalPages, findsOneWidget);

    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion changes issues without animated translation',
      (tester) async {
    await _pump(tester,
        controller: _JournalDiscovery(_shenzhenRoutes), reducedMotion: true);
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pump();
    expect(find.text('02'), findsOneWidget);
    expect(_journalPages, findsOneWidget);
    final selected = _routeCard('shenzhen-mixc-world');
    final origin = tester.getTopLeft(selected);
    final gesture = await tester.startGesture(tester.getCenter(_journalSwipe));
    await gesture.moveBy(const Offset(-24, 0));
    await gesture.moveBy(const Offset(-120, 0),
        timeStamp: const Duration(milliseconds: 150));
    await tester.pump();
    expect(tester.getTopLeft(selected), origin);
    expect(find.text('02'), findsOneWidget);
    await gesture.up(timeStamp: const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('03'), findsOneWidget);
    expect(_routeCard('shenzhen-dameisha'), findsOneWidget);
    expect(_journalPages, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a single issue stays still and an empty inventory remains usable',
      (tester) async {
    final controller = _JournalDiscovery([_shenzhenRoutes.first]);
    await _pump(tester, controller: controller);
    final selected = _routeCard('shenzhen-mixc-world');
    final origin = tester.getTopLeft(selected);
    await tester.drag(_journalSwipe, const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下一期随刊'));
    await tester.pumpAndSettle();
    expect(find.text('01'), findsOneWidget);
    expect(tester.getTopLeft(selected), origin);
    expect(_journalPages, findsOneWidget);

    controller.replaceRoutes([]);
    await tester.pumpAndSettle();
    expect(find.text('下一本随刊，\n正在慢慢生长。'), findsOneWidget);
    expect(find.text('选择另一座城市'), findsOneWidget);
    expect(_journalPages, findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Finder get _journalSwipe => find.byKey(const ValueKey('journal-swipe'));
Finder _routeCard(String slug) => find.byKey(ValueKey('route-card-$slug'));
Finder get _journalPages => find.byWidgetPredicate((widget) =>
    widget is Transform &&
    widget.key is ValueKey<String> &&
    (widget.key! as ValueKey<String>).value.startsWith('journal-page-'));

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  String? tab,
  DiscoveryController? controller,
  bool reducedMotion = false,
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
        discoveryControllerProvider.overrideWith(
          () => controller ?? _TestDiscovery(),
        ),
        activeTourControllerProvider.overrideWith(_TestTour.new),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
      ),
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

const _shenzhen = CityExperience(
  id: 'shenzhen',
  slug: 'shenzhen',
  name: '深圳',
  subtitle: '',
  heroImage: '',
);
const _guangzhou = CityExperience(
  id: 'guangzhou',
  slug: 'guangzhou',
  name: '广州',
  subtitle: '',
  heroImage: '',
);

// Reproduce the original Shenzhen failure: only Nantou was featured. Place it
// after two regular routes to verify promotion preserves each group's order.
final _shenzhenRoutes = [
  _journalRoute('shenzhen-mixc-world', '万象天地'),
  _journalRoute('shenzhen-dameisha', '大梅沙'),
  _journalRoute('nantou-time-layers', '南头古城', featured: true),
  _journalRoute('shenzhen-wutong-mountain', '梧桐山'),
];

RouteExperience _journalRoute(String slug, String title,
        {bool featured = false}) =>
    RouteExperience(
      id: slug,
      slug: slug,
      title: title,
      subtitle: '城市故事',
      description: '步行路线',
      durationMinutes: 45,
      distanceKm: 1.5,
      difficulty: '轻松',
      theme: '街区',
      heroImage: '',
      contentStatus: 'published',
      stops: const [],
      isFeatured: featured,
    );

class _JournalDiscovery extends DiscoveryController {
  _JournalDiscovery(this.routes);
  final List<RouteExperience> routes;

  DiscoveryState _state(CityExperience city, List<RouteExperience> routes) =>
      DiscoveryState(
        cities: const [_shenzhen, _guangzhou],
        city: city,
        catalog: CityDiscoveryCatalog(routes: routes),
        cards: routes.map((route) => ScenicAreaCard(route: route)).toList(),
        revision: 0,
      );

  @override
  Future<DiscoveryState> build() async => _state(_shenzhen, routes);

  @override
  Future<DiscoveryStartupAction> prepareColdStart() async =>
      DiscoveryStartupAction.completed;

  void replaceRoutes(List<RouteExperience> routes) {
    state = AsyncData(_state(state.requireValue.city!, routes));
  }

  @override
  Future<void> switchCity(String citySlug) async {
    state = AsyncData(_state(_guangzhou, [
      _journalRoute('guangzhou-first', '广州第一站'),
      _journalRoute('guangzhou-second', '广州第二站'),
    ]));
  }
}
