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

    expect(find.text('梧桐树下的城市切片'), findsOneWidget);
    await tester.ensureVisible(find.text('梧桐树下的城市切片'));
    await tester.tap(find.text('梧桐树下的城市切片'));
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
      scrollable: find.byType(Scrollable).first,
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
    await tester.ensureVisible(find.text('梧桐树下的城市切片'));
    await tester.tap(find.text('梧桐树下的城市切片'));
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
    await tester.ensureVisible(find.text('梧桐树下的城市切片'));
    await tester.tap(find.text('梧桐树下的城市切片'));
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

  testWidgets('swipes between every route returned by the backend',
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

    await tester.tap(find.text('山海之间的故事'));
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

    expect(find.text('这座城市还没有开放路线'), findsOneWidget);
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

class _RecordingRepository extends DemoExperienceRepository {
  _RecordingRepository() : super(latency: Duration.zero);

  String? requestedCity;

  @override
  Future<List<RouteExperience>> routesForCity(String citySlug) {
    requestedCity = citySlug;
    return super.routesForCity(citySlug);
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
  Future<List<RouteExperience>> routesForCity(String citySlug) async =>
      const [_oldHarborRoute, _mountainCoastRoute];

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
  Future<List<RouteExperience>> routesForCity(String citySlug) async {
    requestedCity = citySlug;
    return const [];
  }
}

class _EmptyCatalogRepository extends _TwoRouteRepository {
  @override
  Future<List<RouteExperience>> routesForCity(String citySlug) async =>
      const [];
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
  stops: [],
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
  contentStatus: 'in_review',
  stopCount: 5,
  stops: [],
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
