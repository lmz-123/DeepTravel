import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/app.dart';
import 'package:jiandi/core/router/app_router.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/data/demo_content.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/discovery_location.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

void main() {
  testWidgets('app routes cannot reopen the retired traveler drawer',
      (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('打开个人档案')));
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE FILE / 见地档案'), findsOneWidget);
    expect(find.byTooltip('打开旅行者菜单'), findsNothing);
    expect(find.byType(Drawer, skipOffstage: false), findsNothing);

    await tester.dragFrom(const Offset(1, 300), const Offset(280, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer, skipOffstage: false), findsNothing);
    expect(find.text('PRIVATE FILE / 见地档案'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/');
    expect(find.bySemanticsLabel(RegExp('打开个人档案')), findsOneWidget);

    appRouter.go('/profile');
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE FILE / 见地档案'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/');
    expect(find.bySemanticsLabel(RegExp('打开个人档案')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal route opens a quiet full chapter directory',
      (tester) async {
    await _pumpApp(tester);
    await _openFeatured(tester);
    await tester
        .ensureVisible(find.byKey(const ValueKey('route-directory-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-directory-entry')));
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
    // Bring it above the floating navigation, not merely inside the viewport.
    await Scrollable.ensureVisible(tester.element(entrance), alignment: .35);
    await tester.pumpAndSettle();
    await tester.tap(entrance);
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('city-short-story-demo-home-story')));
    await tester.pumpAndSettle();
    expect(find.text('城墙今天想说点什么'), findsOneWidget);
    expect(find.byTooltip('播放故事'), findsOneWidget);
  });

  testWidgets(
      'reading-only route keeps its manual and removes the old field controls',
      (tester) async {
    await _pumpApp(tester);
    await _openFeatured(tester);
    expect(find.text('开启随行'), findsNothing);
    expect(find.text('去随行'), findsNothing);
    expect(find.text('行走准备'), findsNothing);
    expect(find.text('到现场，开始行走'), findsNothing);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(JiandiApp)),
        listen: false);
    expect(container.read(journeyControllerProvider).session, isNull);
    expect(container.read(activeTourControllerProvider).session, isNull);

    await tester
        .ensureVisible(find.byKey(const ValueKey('route-directory-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('route-directory-entry')));
    await tester.pumpAndSettle();
    expect(find.text('本刊目录'), findsOneWidget);
    expect(find.text('我已到达，开始观察'), findsNothing);
    expect(container.read(journeyControllerProvider).session, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'saved reading-only journey link returns to its manual without GPS and supports back',
      (tester) async {
    final tracker = _NoTourLocation();
    final repository = _PublishedDemoRepository();
    await _pumpApp(tester, repository: repository, locationTracker: tracker);
    final container = ProviderScope.containerOf(
        tester.element(find.byType(JiandiApp)),
        listen: false);
    final route = (await tester
        .runAsync(() => repository.routeBySlug('wukang-urban-slices')))!;
    const session = JourneySession(
      id: 'saved-legacy-journey',
      routeId: 'route-wukang',
      status: 'active',
      currentStopPosition: 1,
      arrivedStopId: null,
      answeredStopIds: {},
      progress: 0,
    );
    container.read(journeyControllerProvider.notifier).resume(route, session);

    appRouter.go('/journey/saved-legacy-journey');
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path,
        '/route/wukang-urban-slices');
    expect(find.byKey(const ValueKey('route-directory-entry')), findsOneWidget);
    expect(find.text('我已到达，开始观察'), findsNothing);
    expect(container.read(journeyControllerProvider).session, same(session));
    expect(container.read(activeTourControllerProvider).session, isNull);
    expect(tracker.permissionRequests, 0);
    expect(tracker.sampleSubscriptions, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('城市随刊'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
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
    expect(find.text('城市随刊'), findsNWidgets(2));
  });
}

Future<void> _pumpApp(WidgetTester tester,
    {DemoExperienceRepository? repository,
    LocationTracker? locationTracker}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  appRouter.go('/');
  await tester.pumpWidget(ProviderScope(overrides: [
    experienceRepositoryProvider
        .overrideWithValue(repository ?? _PublishedDemoRepository()),
    currentLocationSourceProvider.overrideWithValue(_NoLocation()),
    if (locationTracker != null)
      locationTrackerProvider.overrideWithValue(locationTracker),
  ], child: const JiandiApp()));
  await tester.pumpAndSettle();
}

Future<void> _openFeatured(WidgetTester tester) async {
  final card = find.byKey(const ValueKey('route-card-wukang-urban-slices'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
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

// The production demo stays unverified. Navigation tests explicitly use a
// published fixture so they exercise the same journal eligibility as the API.
class _PublishedDemoRepository extends DemoExperienceRepository {
  _PublishedDemoRepository() : super(latency: Duration.zero);

  @override
  Future<CityDiscoveryCatalog> discoveryForCity(String citySlug) async =>
      CityDiscoveryCatalog(routes: [_publishedDemoRoute]);

  @override
  Future<RouteExperience> routeBySlug(String slug) async {
    if (slug != demoRoute.slug) throw StateError('路线不存在');
    return _publishedDemoRoute;
  }
}

final _publishedDemoRoute = RouteExperience(
  id: demoRoute.id,
  slug: demoRoute.slug,
  title: demoRoute.title,
  subtitle: demoRoute.subtitle,
  description: demoRoute.description,
  durationMinutes: demoRoute.durationMinutes,
  distanceKm: demoRoute.distanceKm,
  difficulty: demoRoute.difficulty,
  theme: demoRoute.theme,
  heroImage: demoRoute.heroImage,
  contentStatus: 'published',
  stops: demoRoute.stops,
  isFeatured: demoRoute.isFeatured,
  stopCount: demoRoute.stopCount,
  audioTour: demoRoute.audioTour,
  manualChapters: demoRoute.manualChapters,
  district: demoRoute.district,
  cityName: demoRoute.cityName,
  citySlug: demoRoute.citySlug,
  pretrip: demoRoute.pretrip,
  predeparture: demoRoute.predeparture,
  centerLatitude: demoRoute.centerLatitude,
  centerLongitude: demoRoute.centerLongitude,
);

class _RecordingRepository extends _PublishedDemoRepository {
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

class _NoTourLocation implements LocationTracker {
  int permissionRequests = 0;
  int sampleSubscriptions = 0;

  @override
  Future<TourLocationPermission> requestPermission() async {
    permissionRequests += 1;
    return TourLocationPermission.denied;
  }

  @override
  Stream<LocationSample> samples() {
    sampleSubscriptions += 1;
    return const Stream.empty();
  }

  @override
  Future<void> stop() async {}
}
