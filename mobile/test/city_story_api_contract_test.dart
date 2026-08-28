import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/experience/data/api_experience_repository.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/city_story.dart';
import 'package:jiandi/features/experience/domain/home_story.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_page.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/route_detail_page.dart';

void main() {
  test('home modules preserve backend labels and actionable empty metadata',
      () async {
    final repository = _repository((path) {
      if (path.endsWith('/stories')) {
        return {
          'data': {
            'modules': [
              {
                'key': 'today_city_story',
                'title': '城市故事',
                'primary': true,
                'items': [_story],
              },
              for (final key in const [
                'street_corner_3min',
                'city_small_thing',
                'overlooked_detail',
                'today_destination',
              ])
                {'key': key, 'title': key, 'primary': false, 'items': []},
            ],
            'empty': false,
            'fallback_cities': [],
          },
        };
      }
      throw StateError(path);
    });

    final home = await repository.cityStoryHome('shenzhen');

    expect(home.modules, hasLength(5));
    expect(home.modules.first.primary, isTrue);
    expect(home.modules.first.items.single.contentType, '未来新增内容类型');
    expect(home.modules.first.items.single.themes, ['未来主题']);
    expect(home.modules.first.items.single.story.observableDetail, '墙脚有一块旧砖');
  });

  test('route detail exposes pretrip stories without arrival or quiz fields',
      () async {
    final repository = _repository((path) {
      if (path == '/routes/route-a') {
        return {
          'data': {
            ..._route,
            'pretrip': {
              'available': true,
              'theme_story': _story,
              'story_directions': [
                {
                  'catalog_id': 'catalog-a',
                  'title': '先看城墙',
                  'summary': '顺序只是一种建议',
                  'order': 3,
                  'advisory': true,
                  'story': _story,
                }
              ],
              'companion_tags': ['未来同行标签'],
              'tips': {
                'safety': ['留意台阶'],
                'rest': ['街角可休息'],
                'accessibility': ['可从平缓入口进入'],
                'weather_adaptation': ['炎热时避开正午'],
              },
              'offline_resources': [
                {
                  'id': 'catalog-a:audio',
                  'kind': 'audio',
                  'url': '/media/story.mp3',
                  'version': 'revision-a',
                  'checksum_sha256': 'abc',
                  'size_bytes': 10,
                }
              ],
              'requires_arrival': false,
              'quiz': null,
              'version': 2,
            },
          },
        };
      }
      throw StateError(path);
    });

    final route = await repository.routeBySlug('route-a');

    expect(route.pretrip?.available, isTrue);
    expect(route.pretrip?.storyDirections.single.order, 3);
    expect(route.pretrip?.companionTags, ['未来同行标签']);
    expect(route.pretrip?.offlineResources.single.version, 'revision-a');
  });

  testWidgets('primary city story card is accessible and opens shared reader',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const DiscoveryPage()),
      GoRoute(
        path: '/story/:catalogId',
        builder: (_, state) => Scaffold(
          body: Text('story:${state.pathParameters['catalogId']}'),
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        discoveryControllerProvider.overrideWith(_StoryDiscoveryController.new),
        archivedActiveJourneysProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('继续我的足迹'), findsNothing);
    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    final sliverKeys = scrollView.slivers.map((sliver) => sliver.key).toList();
    expect(
      sliverKeys.indexOf(const ValueKey('route-selection-section')),
      lessThan(sliverKeys.indexOf(const ValueKey('city-story-section'))),
    );
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.text('城市故事'), findsOneWidget);
    final storyCard = find.bySemanticsLabel(RegExp('未来类型.*街角的旧砖'));
    expect(storyCard, findsOneWidget);
    await tester.scrollUntilVisible(
      storyCard,
      300,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(storyCard);
    await tester.pumpAndSettle();
    expect(find.text('story:catalog-a'), findsOneWidget);
  });

  testWidgets(
      'manual starts with compact predeparture and renders server tags at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        experienceRepositoryProvider.overrideWithValue(
          _PredepartureRepository(),
        ),
      ],
      child: const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: RouteDetailPage(slug: 'route-predeparture'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('predeparture-surface')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('predeparture-play-pause')), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.scrollUntilVisible(
      find.text('老建筑'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('老建筑'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('适合一个人'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('适合一个人'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PredepartureRepository extends DemoExperienceRepository {
  _PredepartureRepository() : super(latency: Duration.zero);

  @override
  Future<RouteExperience> routeBySlug(String slug) async =>
      RouteExperience.fromJson(_routeWithPredeparture);
}

class _StoryDiscoveryController extends DiscoveryController {
  @override
  Future<DiscoveryState> build() async => const DiscoveryState(
        cities: [
          CityExperience(
            id: 'city-a',
            slug: 'shenzhen',
            name: '深圳',
            subtitle: '测试城市',
            heroImage: '',
          ),
        ],
        city: CityExperience(
          id: 'city-a',
          slug: 'shenzhen',
          name: '深圳',
          subtitle: '测试城市',
          heroImage: '',
        ),
        catalog: CityDiscoveryCatalog(routes: []),
        cards: [],
        storyHome: CityStoryHome(
          isEmpty: false,
          fallbackCities: [],
          modules: [
            CityStoryModule(
              key: 'today_city_story',
              title: '城市故事',
              primary: true,
              items: [
                CityStoryCard(
                  story: HomeStory(
                    id: 'catalog-a',
                    arcId: 'arc-a',
                    title: '街角的旧砖',
                    introduction: '三分钟读懂街角',
                    coverImage: '',
                    duration: Duration(minutes: 3),
                    transcript: '文字稿',
                    audioUrl: '',
                    cityName: '深圳',
                    citySlug: 'shenzhen',
                    routeTitle: '南头古城',
                    routeSlug: 'route-a',
                    narratorName: '见地讲述者',
                  ),
                  contentType: '未来类型',
                  themes: ['未来主题'],
                  placeContext: '街角',
                  observableDetail: '旧砖',
                  factStatus: 'documented',
                ),
              ],
            ),
          ],
        ),
        revision: 0,
      );

  @override
  Future<DiscoveryStartupAction> prepareColdStart() async =>
      DiscoveryStartupAction.completed;
}

ApiExperienceRepository _repository(
  Map<String, dynamic> Function(String path) response,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) => handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: response(options.path),
    )),
  ));
  return ApiExperienceRepository(dio, AuthRepository(dio));
}

const _story = {
  'id': 'catalog-a',
  'arc_id': 'arc-a',
  'title': '街角的旧砖',
  'introduction': '三分钟读懂一处街角',
  'cover_image_url': 'https://example.test/cover.jpg',
  'duration_ms': 180000,
  'transcript': '完整文字稿',
  'audio_url': 'https://example.test/story.mp3',
  'city': {'name': '深圳', 'slug': 'shenzhen'},
  'route': {'title': '南头古城', 'slug': 'route-a'},
  'narration_profile': {'display_name': '见地讲述者'},
  'content_type': '未来新增内容类型',
  'themes': ['未来主题'],
  'place_context': '南头古城街角',
  'observable_detail': '墙脚有一块旧砖',
  'fact_status': 'documented',
};

const _route = {
  'id': 'route-a',
  'slug': 'route-a',
  'title': '测试路线',
  'subtitle': '测试',
  'description': '测试路线',
  'duration_minutes': 30,
  'distance_km': 1.2,
  'difficulty': '轻松',
  'theme': '城市历史',
  'hero_image': '',
  'content_status': 'published',
  'is_featured': true,
  'stops': [],
};

const _routeWithPredeparture = {
  'id': 'route-predeparture',
  'slug': 'route-predeparture',
  'title': '测试路线',
  'subtitle': '测试',
  'description': '测试路线',
  'duration_minutes': 30,
  'distance_km': 1.2,
  'difficulty': '轻松',
  'theme': '城市历史',
  'hero_image': '',
  'content_status': 'published',
  'is_featured': true,
  'predeparture': {
    'text': '出发前，先简单认识这座城市和眼前这处景点。',
    'script_version': 'v1',
    'transcript_hash': 'hash-a',
    'audio': {
      'track_id': 'track-a',
      'url': 'https://cdn.example.test/predeparture.mp3',
      'mime_type': 'audio/mpeg',
      'size_bytes': 100,
      'duration_ms': 9000,
    },
    'narration_profile': {'display_name': '见地讲述者'},
  },
  'stops': [
    {
      'id': 'stop-a',
      'position': 1,
      'title': '城墙转角',
      'kicker': '第一站',
      'address': '测试地址',
      'latitude': 22.5,
      'longitude': 114.0,
      'story_title': '旧砖故事',
      'story_body': '正文',
      'image': '',
      'insight': '观察灰缝',
      'experience_tags': ['老建筑', '适合一个人'],
      'challenge': null,
    }
  ],
};
