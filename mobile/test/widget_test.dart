import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/app.dart';
import 'package:jiandi/core/router/app_router.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/discovery_location.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

void main() {
  testWidgets('journal route opens a quiet full chapter directory',
      (tester) async {
    await _pumpApp(tester);
    await _openFeatured(tester);
    await tester.tap(find.text('翻开这段旅程'));
    await tester.pumpAndSettle();
    expect(find.text('本刊目录'), findsOneWidget);
    expect(find.text('我已到达，开始观察'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('city short stories remain reachable without autoplay',
      (tester) async {
    await _pumpApp(tester);
    final entrance = find.byKey(const ValueKey('city-short-stories-action'));
    await tester.scrollUntilVisible(entrance, 420,
        scrollable: _verticalScrollable().first);
    await tester.tap(entrance);
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('city-short-story-demo-home-story')));
    await tester.pumpAndSettle();
    expect(find.text('城墙今天想说点什么'), findsOneWidget);
    expect(find.byTooltip('播放故事'), findsOneWidget);
  });

  testWidgets('explicit on-site entry preserves legacy arrival and observation',
      (tester) async {
    await _pumpApp(tester);
    await _openFeatured(tester);
    final field = find.text('到现场，开始行走');
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    final arrive = find.text('我已到达，开始观察');
    await tester.ensureVisible(arrive);
    await tester.tap(arrive);
    await tester.pumpAndSettle();
    expect(find.text('一栋顺着街角生长的建筑'), findsOneWidget);
    expect(find.text('观察一下'), findsOneWidget);
    expect(find.textContaining('一艘停靠街角的船'), findsOneWidget);
  });

  testWidgets('system back from a field journey returns to journal',
      (tester) async {
    await _pumpApp(tester);
    await _openFeatured(tester);
    await tester.ensureVisible(find.text('到现场，开始行走'));
    await tester.tap(find.text('到现场，开始行走'));
    await tester.pumpAndSettle();
    expect(find.text('我已到达，开始观察'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('深圳'), findsOneWidget);
    expect(find.text('城市随刊'), findsOneWidget);
  });

  testWidgets('defaults to configured Shenzhen and reloads after city change',
      (tester) async {
    final repository = _RecordingRepository();
    await _pumpApp(tester, repository: repository);
    expect(find.text('深圳'), findsOneWidget);
    expect(repository.requestedCity, 'shenzhen');
    await tester.tap(find.byTooltip('选择城市'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上海').last);
    await tester.pumpAndSettle();
    expect(find.text('上海'), findsOneWidget);
    expect(repository.requestedCity, 'shanghai');
  });

  testWidgets('large backend city catalogue can be searched before selection',
      (tester) async {
    final repository = _ManyCityRepository();
    await _pumpApp(tester, repository: repository);
    await tester.tap(find.byTooltip('选择城市'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '第 19 城');
    await tester.pump();
    expect(find.text('第 19 城'), findsNWidgets(2));
    expect(find.text('第 18 城'), findsNothing);
    await tester.tap(find.text('第 19 城').last);
    await tester.pumpAndSettle();
    expect(repository.requestedCity, 'city-19');
  });

  testWidgets('all backend routes remain selectable through the city index',
      (tester) async {
    final repository = _TwoRouteRepository();
    await _pumpApp(tester, repository: repository);
    expect(find.text('旧港码头'), findsNothing);
    expect(find.text('山海栈道'), findsNothing);
    await tester.tap(find.text('路线'));
    await tester.pumpAndSettle();
    expect(find.text('收录 2 条路线'), findsOneWidget);
    final second =
        find.byKey(const ValueKey('atlas-route-route-mountain-coast'));
    await tester.ensureVisible(second);
    await tester
        .tap(find.descendant(of: second, matching: find.text('山海之间的故事')));
    await tester.pumpAndSettle();
    expect(repository.requestedRouteSlug, 'mountain-coast');
    expect(find.text('山海之间的故事'), findsWidgets);
  });

  testWidgets('empty backend catalogue never inserts a fallback route',
      (tester) async {
    await _pumpApp(tester, repository: _EmptyCatalogRepository());
    expect(find.text('下一本随刊，\n正在慢慢生长。'), findsOneWidget);
    expect(find.text('南头古城的时间叠层'), findsNothing);
    expect(find.text('被打开的海湾'), findsNothing);
  });

  testWidgets('journal does not revive archived journey cards', (tester) async {
    await _pumpApp(tester);
    expect(find.text('继续未完成的旧路线'), findsNothing);
    expect(find.textContaining('已定位到'), findsNothing);
    expect(find.text('城市随刊'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester,
    {DemoExperienceRepository? repository}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  appRouter.go('/');
  await tester.pumpWidget(ProviderScope(overrides: [
    experienceRepositoryProvider.overrideWithValue(
        repository ?? DemoExperienceRepository(latency: Duration.zero)),
    currentLocationSourceProvider.overrideWithValue(_NoLocation()),
  ], child: const JiandiApp()));
  await tester.pumpAndSettle();
}

Future<void> _openFeatured(WidgetTester tester) async {
  final card = find.byKey(const ValueKey('route-card-wukang-urban-slices'));
  await tester.ensureVisible(card);
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Finder _verticalScrollable() => find.byWidgetPredicate((widget) =>
    widget is Scrollable && widget.axisDirection == AxisDirection.down);

class _NoLocation implements CurrentLocationSource {
  @override
  Future<DiscoveryPermissionState> permissionState() async =>
      DiscoveryPermissionState.serviceDisabled;
  @override
  Future<DiscoveryLocationSample> currentPosition(
          {required bool requestPermission}) async =>
      throw const DiscoveryLocationFailure(
          DiscoveryLocationFailureReason.serviceDisabled);
}

class _RecordingRepository extends DemoExperienceRepository {
  _RecordingRepository() : super(latency: Duration.zero);

  String? requestedCity;

  @override
  Future<CityDiscoveryCatalog> discoveryForCity(String citySlug) {
    requestedCity = citySlug;
    return super.discoveryForCity(citySlug);
  }
}

class _TwoRouteRepository extends DemoExperienceRepository {
  _TwoRouteRepository() : super(latency: Duration.zero);

  String? requestedRouteSlug;

  @override
  Future<List<CityExperience>> cities() async => const [
        CityExperience(
          id: 'city-coast',
          slug: 'coast-city',
          name: '海滨城',
          subtitle: '由服务端配置的测试城市',
          heroImage: '',
        ),
      ];

  @override
  Future<CityDiscoveryCatalog> discoveryForCity(String citySlug) async =>
      const CityDiscoveryCatalog(
        routes: [_oldHarborRoute, _mountainCoastRoute],
      );

  @override
  Future<RouteExperience> routeBySlug(String slug) async {
    requestedRouteSlug = slug;
    return slug == _mountainCoastRoute.slug
        ? _mountainCoastRoute
        : _oldHarborRoute;
  }
}

class _ManyCityRepository extends DemoExperienceRepository {
  _ManyCityRepository() : super(latency: Duration.zero);

  String? requestedCity;

  @override
  Future<List<CityExperience>> cities() async => List.generate(
        20,
        (index) => CityExperience(
          id: 'city-$index',
          slug: 'city-$index',
          name: '第 $index 城',
          subtitle: '后台配置的第 $index 个目的地',
          heroImage: '',
        ),
      );

  @override
  Future<CityDiscoveryCatalog> discoveryForCity(String citySlug) async {
    requestedCity = citySlug;
    return const CityDiscoveryCatalog(routes: []);
  }
}

class _EmptyCatalogRepository extends _TwoRouteRepository {
  @override
  Future<CityDiscoveryCatalog> discoveryForCity(String citySlug) async =>
      const CityDiscoveryCatalog(routes: []);
}

const _oldHarborRoute = RouteExperience(
  id: 'route-old-harbor',
  slug: 'old-harbor',
  title: '旧港留下的时间',
  subtitle: '从码头读城市',
  description: '由后端返回的第一条路线',
  durationMinutes: 45,
  distanceKm: 1.8,
  difficulty: '轻松',
  theme: '港口生活',
  heroImage: '',
  contentStatus: 'published',
  isFeatured: true,
  stopCount: 5,
  stops: [_oldHarborNode],
  centerLatitude: 22.5,
  centerLongitude: 114,
);

const _mountainCoastRoute = RouteExperience(
  id: 'route-mountain-coast',
  slug: 'mountain-coast',
  title: '山海之间的故事',
  subtitle: '沿海岸寻找变化',
  description: '由后端返回的第二条路线',
  durationMinutes: 55,
  distanceKm: 2.2,
  difficulty: '轻松',
  theme: '海岸变迁',
  heroImage: '',
  contentStatus: 'published',
  stopCount: 5,
  stops: [_mountainCoastNode],
  centerLatitude: 22.6,
  centerLongitude: 114.1,
);

const _oldHarborNode = ExperienceStop(
  id: 'old-harbor-node',
  position: 1,
  title: '旧港码头',
  kicker: '内部节点',
  address: '旧港',
  latitude: 22.5,
  longitude: 114,
  storyTitle: '旧港节点故事',
  storyBody: '节点内容',
  image: '',
  insight: '节点观察',
  challenge: Challenge(id: '', prompt: '', hint: '', options: []),
);

const _mountainCoastNode = ExperienceStop(
  id: 'mountain-coast-node',
  position: 1,
  title: '山海栈道',
  kicker: '内部节点',
  address: '海岸',
  latitude: 22.6,
  longitude: 114.1,
  storyTitle: '山海节点故事',
  storyBody: '节点内容',
  image: '',
  insight: '节点观察',
  challenge: Challenge(id: '', prompt: '', hint: '', options: []),
);
