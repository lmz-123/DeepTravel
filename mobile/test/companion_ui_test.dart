import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/application/nearby_story_points.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_page.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

/// Companion regression coverage is deliberately kept separate from release
/// approval. The tests assert the native phone surface size, keep labeled
/// 390×844 and 360×800 fixtures, and exercise the interaction state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, file) in [
      ('Noto Serif SC', 'NotoSerifSC.ttf'),
      ('Noto Sans SC', 'NotoSansSC.ttf'),
      ('Inter', 'Inter.ttf'),
      ('Georgia', 'Gelasio.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('assets/fonts/$file').readAsBytes(),
            ),
          ),
        );
      if (family == 'Georgia') {
        loader.addFont(
          Future.value(
            ByteData.sublistView(
              await File('assets/fonts/Gelasio-Italic.ttf').readAsBytes(),
            ),
          ),
        );
      }
      await loader.load();
    }
  });

  for (final size in [const Size(390, 844), const Size(360, 800)]) {
    testWidgets('companion idle fits ${size.width.toInt()}px mobile surface',
        (tester) async {
      await _pump(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('把屏幕退到身后'), findsOneWidget);
      expect(find.text('让位置，'), findsOneWidget);
      expect(find.byKey(const ValueKey('companion-signal')), findsOneWidget);
      expect(find.text('等你开启'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('companion-screen'))),
        size,
      );
      await expectLater(
        find.byKey(const ValueKey('companion-screen')),
        matchesGoldenFile('goldens/companion-idle-${size.width.toInt()}.png'),
      );
    });
  }

  testWidgets('route selection stays on companion and does not start GPS',
      (tester) async {
    final harness = _CompanionHarness();
    await _pump(tester, harness: harness);

    final second = find.byKey(const ValueKey('companion-route-route-1'));
    await _reveal(tester, second);
    await tester.tap(second);
    await tester.pump();

    expect(find.text('随行'), findsWidgets);
    expect(find.text('detail:route-1'), findsNothing);
    expect(harness.tour.startCalls, 0);
    expect(harness.journey.startCalls, 0);
    expect(
      tester.getSemantics(second).getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting disables repeated taps while preparing',
      (tester) async {
    final harness =
        _CompanionHarness(startDelay: const Duration(milliseconds: 80));
    await _pump(tester, harness: harness);

    final primary = find.byKey(const ValueKey('companion-primary'));
    await _reveal(tester, primary);
    await tester.tap(primary);
    await tester.pump();
    expect(find.text('准备中…'), findsOneWidget);

    await _reveal(tester, primary);
    await tester.tap(primary);
    expect(harness.journey.startCalls, 1);
    expect(harness.tour.startCalls, 1);

    await tester.pump(const Duration(milliseconds: 100));
    expect(harness.tour.startCalls, 1);
    expect(find.text('暂停随行'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'nearby story requires explicit playback and supports pause/resume',
      (tester) async {
    final harness = _CompanionHarness();
    await _pump(tester, harness: harness);

    final primary = find.byKey(const ValueKey('companion-primary'));
    await _reveal(tester, primary);
    await tester.tap(primary);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('暂停随行'), findsOneWidget);

    await _reveal(tester, find.text('暂停随行'));
    await tester.tap(find.text('暂停随行'));
    await tester.pump();
    expect(find.text('继续寻找'), findsOneWidget);
    await _reveal(tester, find.text('继续寻找'));
    await tester.tap(find.text('继续寻找'));
    await tester.pump();
    expect(find.text('暂停随行'), findsOneWidget);

    await _reveal(tester, find.text('模拟靠近一处线索'));
    await tester.tap(find.text('模拟靠近一处线索'));
    await tester.pump();
    expect(find.text('播放这一段'), findsOneWidget);
    expect(harness.tour.playCalls, 0);

    await _reveal(tester, find.text('播放这一段'));
    await tester.tap(find.text('播放这一段'));
    await tester.pump();
    expect(find.text('暂停讲述'), findsOneWidget);
    expect(harness.tour.playCalls, 1);

    await _reveal(tester, find.text('暂停讲述'));
    await tester.tap(find.text('暂停讲述'));
    await tester.pump();
    expect(find.text('继续寻找'), findsOneWidget);
    await _reveal(tester, find.text('继续寻找'));
    await tester.tap(find.text('继续寻找'));
    await tester.pump();
    expect(find.text('暂停随行'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing selected route resets the page to idle after stop',
      (tester) async {
    final harness = _CompanionHarness();
    await _pump(tester, harness: harness);
    final primary = find.byKey(const ValueKey('companion-primary'));
    await _reveal(tester, primary);
    await tester.tap(primary);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('暂停随行'), findsOneWidget);

    await _reveal(tester, find.text('结束本次随行'));
    await tester.tap(find.text('结束本次随行'));
    await tester.pump();
    expect(find.text('开启随行'), findsOneWidget);
    expect(find.text('等你开启'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  _CompanionHarness? harness,
}) async {
  final fixture = harness ?? _CompanionHarness();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '/?tab=companion',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) => DiscoveryPage(
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: '/route/:slug',
        builder: (_, state) => Scaffold(
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
        discoveryControllerProvider.overrideWith(() => _TestDiscovery()),
        journeyControllerProvider.overrideWith(() => fixture.journey),
        activeTourControllerProvider.overrideWith(() => fixture.tour),
      ],
      child: RepaintBoundary(
        key: const ValueKey('companion-screen'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: AppTheme.light,
        ),
      ),
    ),
  );
  // The companion signal deliberately has a repeating breath animation, so
  // pumpAndSettle would wait forever. A bounded pump lets async providers
  // finish without treating the animation as unfinished work.
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    280,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 50));
}

class _CompanionHarness {
  _CompanionHarness({this.startDelay = Duration.zero})
      : journey = _TestJourney(),
        tour = _TestTour(startDelay: startDelay);

  final Duration startDelay;
  final _TestJourney journey;
  final _TestTour tour;
}

class _TestJourney extends JourneyController {
  var startCalls = 0;

  @override
  JourneyUiState build() => const JourneyUiState();

  @override
  Future<String?> start(RouteExperience route) async {
    startCalls += 1;
    final session = JourneySession(
      id: 'session-${route.id}',
      routeId: route.id,
      status: 'active',
      currentStopPosition: 1,
      arrivedStopId: null,
      answeredStopIds: const {},
      progress: 0,
    );
    state = JourneyUiState(route: route, session: session);
    return session.id;
  }
}

class _TestTour extends ActiveTourController {
  _TestTour({this.startDelay = Duration.zero});

  final Duration startDelay;
  var startCalls = 0;
  var playCalls = 0;

  @override
  ActiveTourState build() => const ActiveTourState();

  @override
  Future<void> start(RouteExperience route, JourneySession session) async {
    startCalls += 1;
    state = ActiveTourState(
      status: 'preparing',
      route: route,
      session: session,
      locationMode: TourLocationMode.simulated,
      isBusy: true,
    );
    if (startDelay > Duration.zero) await Future<void>.delayed(startDelay);
    state = ActiveTourState(
      status: 'simulated',
      route: route,
      session: session,
      locationMode: TourLocationMode.simulated,
      locationMessage: '模拟定位已开启',
      nearbyStoryPoints: [
        NearbyStoryPoint(
          fragment: _fragment,
          status: NearbyStoryPointStatus.outside,
        ),
      ],
    );
  }

  @override
  Future<void> triggerNextDemo({bool autoPlay = false}) async {
    state = state.copyWith(
      status: 'simulated',
      current: _fragment,
      nearbyStoryPoints: [
        const NearbyStoryPoint(
          fragment: _fragment,
          status: NearbyStoryPointStatus.inRange,
          distanceMeters: 80,
        ),
      ],
      locationMessage: '一段声音就在附近',
    );
  }

  @override
  Future<void> togglePlayback() async {
    playCalls += state.isPlaying ? 0 : 1;
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  @override
  Future<void> pauseTour() async {
    state = state.copyWith(status: 'paused', isPlaying: false);
  }

  @override
  Future<void> resumeTour({bool resumeAudio = true}) async {
    state = state.copyWith(
      status: 'simulated',
      isPlaying: false,
      clearCurrent: true,
      nearbyStoryPoints: const [],
    );
  }

  @override
  Future<void> stopTour() async {
    state = const ActiveTourState();
  }
}

class _TestDiscovery extends DiscoveryController {
  @override
  Future<DiscoveryState> build() async => DiscoveryState(
        cities: const [_city],
        city: _city,
        catalog: CityDiscoveryCatalog(routes: _routes),
        cards: _routes.map((route) => ScenicAreaCard(route: route)).toList(),
        revision: 0,
      );

  @override
  Future<DiscoveryStartupAction> prepareColdStart() async =>
      DiscoveryStartupAction.completed;
}

const _city = CityExperience(
  id: 'test-city',
  slug: 'test-city',
  name: '测试城',
  subtitle: '城市故事',
  heroImage: '',
);

final _routes = [_route('route-0', '测试路线 0'), _route('route-1', '测试路线 1')];

RouteExperience _route(String id, String title) => RouteExperience(
      id: id,
      slug: id,
      title: title,
      subtitle: '慢慢走，才看得见',
      description: '一条测试用的城市声音路线。',
      durationMinutes: 45,
      distanceKm: 2.1,
      difficulty: '轻松',
      theme: '街区',
      heroImage: '',
      contentStatus: 'published',
      stops: const [],
      audioTour: _manifest,
    );

const _manifest = AudioTourManifest(
  title: '测试声音路线',
  centralQuestion: '一座城市如何被听见？',
  scriptVersion: 'fixture-1',
  reviewState: 'approved',
  fieldAuditState: 'approved',
  productionReady: true,
  demoLabel: '测试夹具',
  contentMethod: 'field',
  downloadSizeBytes: 1,
  fragments: [_fragment],
);

const _fragment = StoryFragment(
  id: 'fragment-1',
  position: 1,
  safePreview: '一段关于街区的声音。',
  interactionType: 'listen',
  reviewState: 'approved',
  triggerRegion: TriggerRegion(
    latitude: 22.5431,
    longitude: 114.0579,
    entryRadiusM: 100,
    exitRadiusM: 130,
    maxAccuracyM: 50,
    qualifyingSamples: 1,
    sampleWindowSeconds: 5,
    cooldownSeconds: 30,
    auditState: 'approved',
  ),
  audio: NarrationAsset(
    url: 'https://fixture.test/story.mp3',
    mimeType: 'audio/mpeg',
    sizeBytes: 1,
    scriptVersion: 'fixture-1',
  ),
  title: '街角的回声',
  transcript: '你听见了吗？',
);
