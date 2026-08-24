import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/app.dart';
import 'package:jiandi/core/router/app_router.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

void main() {
  testWidgets('featured route can start in two taps', (tester) async {
    appRouter.go('/');
    final repository = DemoExperienceRepository(latency: Duration.zero);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();

    final firstScenicArea = find.byKey(
      const ValueKey('route-card-wukang-urban-slices'),
    );
    expect(firstScenicArea, findsOneWidget);
    await _scrollToScenic(tester);
    expect(
      tester.getSize(find.byKey(const ValueKey('route-carousel'))).height,
      505,
    );
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('route-hero-wukang-urban-slices'),
            ),
          )
          .height,
      276,
    );
    await tester.tap(firstScenicArea);
    await tester.pumpAndSettle();

    expect(find.text('开始这段探索'), findsOneWidget);
    await tester.tap(find.text('开始这段探索'));
    await tester.pumpAndSettle();

    expect(find.text('我已到达，开始观察'), findsOneWidget);
  });

  testWidgets('home story action opens reviewed story without autoplay',
      (tester) async {
    appRouter.go('/');
    final repository = DemoExperienceRepository(latency: Duration.zero);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-random-story-action')),
      420,
      scrollable: _verticalScrollable(),
    );
    await tester.tap(find.byKey(const ValueKey('home-random-story-action')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('城墙今天想说点什么'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('城墙今天想说点什么'), findsOneWidget);
    expect(find.text('给自己三分钟，听一阵海风如何吹进一座老城。'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-story-play-pause')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byTooltip('播放故事'), findsOneWidget);
  });

  testWidgets('arrival reveals story and observation challenge',
      (tester) async {
    appRouter.go('/');
    final repository = DemoExperienceRepository(latency: Duration.zero);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();
    final firstScenicArea = find.byKey(
      const ValueKey('route-card-wukang-urban-slices'),
    );
    await _scrollToScenic(tester);
    await tester.tap(firstScenicArea);
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始这段探索'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('我已到达，开始观察'));
    await tester.tap(find.text('我已到达，开始观察'));
    await tester.pumpAndSettle();

    expect(find.text('一栋顺着街角生长的建筑'), findsOneWidget);
    expect(find.text('观察一下'), findsOneWidget);
    expect(find.textContaining('一艘停靠街角的船'), findsOneWidget);
  });

  testWidgets('system back from a journey returns to discovery',
      (tester) async {
    appRouter.go('/');
    final repository = DemoExperienceRepository(latency: Duration.zero);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();
    final firstScenicArea = find.byKey(
      const ValueKey('route-card-wukang-urban-slices'),
    );
    await _scrollToScenic(tester);
    await tester.tap(firstScenicArea);
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始这段探索'));
    await tester.pumpAndSettle();

    expect(find.text('我已到达，开始观察'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('深圳'), findsOneWidget);
    expect(find.byKey(const ValueKey('route-carousel')), findsOneWidget);
  });

  testWidgets('defaults to configured Shenzhen and reloads after city change',
      (tester) async {
    appRouter.go('/');
    final repository = _RecordingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('深圳'), findsOneWidget);
    expect(repository.requestedCity, 'shenzhen');

    await tester.tap(find.byTooltip('选择城市'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上海').last);
    await tester.pumpAndSettle();

    expect(find.text('上海'), findsOneWidget);
    expect(repository.requestedCity, 'shanghai');
  });

  testWidgets('large backend city catalog filters immediately', (tester) async {
    appRouter.go('/');
    final repository = _ManyCityRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('选择城市'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '第 19 城');
    await tester.pump();
    expect(find.text('第 19 城'), findsNWidgets(2));
    expect(find.text('第 18 城'), findsNothing);

    await tester.tap(find.text('第 19 城').last);
    await tester.pumpAndSettle();
    expect(repository.requestedCity, 'city-19');
  });

  testWidgets('swipes between scenic areas without surfacing their nodes',
      (tester) async {
    appRouter.go('/');
    final repository = _TwoRouteRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('route-card-old-harbor')), findsOneWidget);
    expect(find.byKey(const ValueKey('route-card-mountain-coast')),
        findsOneWidget);
    expect(find.text('旧港码头'), findsNothing);
    expect(find.text('山海栈道'), findsNothing);

    await _scrollToScenic(tester);

    await tester.fling(
      find.byKey(const ValueKey('route-carousel')),
      const Offset(-700, 0),
      1200,
    );
    await tester.pumpAndSettle();

    final firstIndicator = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('route-indicator-0')),
    );
    final secondIndicator = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('route-indicator-1')),
    );
    expect(firstIndicator.constraints?.maxWidth, 7);
    expect(secondIndicator.constraints?.maxWidth, 24);

    await tester.tap(
      find.byKey(const ValueKey('route-card-mountain-coast')),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedRouteSlug, 'mountain-coast');
    expect(find.text('山海之间的故事'), findsWidgets);
  });

  testWidgets('empty backend catalog stays neutral without route fallback',
      (tester) async {
    appRouter.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          experienceRepositoryProvider
              .overrideWithValue(_EmptyCatalogRepository()),
        ],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('这座城市还没有开放景区'), findsOneWidget);
    expect(find.text('南头古城的时间叠层'), findsNothing);
    expect(find.text('被打开的海湾'), findsNothing);
  });

  testWidgets('archived active journey resumes the legacy answer flow',
      (tester) async {
    appRouter.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          experienceRepositoryProvider.overrideWithValue(
            _ArchivedResumeRepository(),
          ),
          archivedActiveJourneysProvider.overrideWith(
            (ref) async => const [
              ResumableJourney(
                route: _archivedQuizRoute,
                session: JourneySession(
                  id: 'archived-journey',
                  routeId: 'archived-route',
                  status: 'active',
                  currentStopPosition: 1,
                  arrivedStopId: null,
                  answeredStopIds: {},
                  progress: 0,
                ),
              ),
            ],
          ),
        ],
        child: const JiandiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('继续未完成的旧路线'), findsOneWidget);
    await tester.tap(find.text('旧版上海观察路线'));
    await tester.pumpAndSettle();

    expect(find.text('我已到达，开始观察'), findsOneWidget);
    await tester.tap(find.text('我已到达，开始观察'));
    await tester.pumpAndSettle();
    expect(find.text('观察一下'), findsOneWidget);
    expect(find.text('旧版问题'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });
}

Finder _verticalScrollable() => find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );

Future<void> _scrollToScenic(WidgetTester tester) async {
  await tester.drag(_verticalScrollable(), const Offset(0, -300));
  await tester.pumpAndSettle();
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

class _ArchivedResumeRepository extends DemoExperienceRepository {
  _ArchivedResumeRepository() : super(latency: Duration.zero);

  @override
  Future<JourneySession> arrive(String journeyId) async => const JourneySession(
        id: 'archived-journey',
        routeId: 'archived-route',
        status: 'active',
        currentStopPosition: 1,
        arrivedStopId: 'old-stop',
        answeredStopIds: {},
        progress: 0,
      );
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

const _archivedQuizRoute = RouteExperience(
  id: 'archived-route',
  slug: 'archived-shanghai-quiz',
  title: '旧版上海观察路线',
  subtitle: '仅供已有旅程继续',
  description: '已归档路线',
  durationMinutes: 30,
  distanceKm: 1,
  difficulty: '轻松',
  theme: '城市观察',
  heroImage: '',
  contentStatus: 'archived',
  stops: [
    ExperienceStop(
      id: 'old-stop',
      position: 1,
      title: '旧站点',
      kicker: '继续观察',
      address: '上海',
      latitude: 31.2,
      longitude: 121.4,
      storyTitle: '旧版故事',
      storyBody: '旧版故事正文',
      image: '',
      insight: '旧版观察',
      challenge: Challenge(
        id: 'old-question',
        prompt: '旧版问题',
        hint: '提示',
        options: ['A', 'B'],
      ),
    ),
  ],
);
