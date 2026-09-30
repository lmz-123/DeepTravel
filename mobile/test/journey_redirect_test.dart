import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/journey_redirect_page.dart';

void main() {
  testWidgets('cached active journey returns to companion without restarting',
      (tester) async {
    final initial = ActiveTourState(
      status: 'paused',
      route: _audioRoute,
      session: _session,
      position: const Duration(seconds: 29),
    );
    final fixture = _Harness(active: initial);
    final router = await _pump(tester, fixture: fixture);

    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(router.routeInformationProvider.value.uri.queryParameters,
        {'tab': 'companion', 'route': _audioRoute.slug});
    expect(fixture.tour.snapshot, same(initial));
    expect(fixture.tour.starts, 0);
    expect(fixture.tour.stops, 0);
    expect(fixture.journey.starts, 0);
    expect(fixture.lookups, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cached journey handoff does not start location or audio',
      (tester) async {
    final fixture = _Harness(
      journey: JourneyUiState(route: _audioRoute, session: _session),
    );
    final router = await _pump(tester, fixture: fixture);

    expect(router.routeInformationProvider.value.uri.queryParameters,
        {'tab': 'companion', 'route': _audioRoute.slug});
    expect(fixture.tour.starts, 0);
    expect(fixture.journey.starts, 0);
    expect(fixture.lookups, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history link restores its route without replacing another walk',
      (tester) async {
    final initial = ActiveTourState(
      status: 'monitoring',
      route: _otherRoute,
      session: _otherSession,
      position: const Duration(seconds: 51),
    );
    final fixture = _Harness(
      active: initial,
      journey: JourneyUiState(route: _otherRoute, session: _otherSession),
      context: _context(_audioRoute),
    );
    final router = await _pump(tester, fixture: fixture, userId: 'user-a');

    expect(router.routeInformationProvider.value.uri.queryParameters,
        {'tab': 'companion', 'route': _audioRoute.slug});
    expect(fixture.lookups, [const UserJourneyKey('user-a', 'journey-a')]);
    expect(fixture.tour.snapshot, same(initial));
    expect(fixture.journey.snapshot.session?.id, 'journey-other');
    expect(fixture.tour.starts, 0);
    expect(fixture.tour.stops, 0);
    expect(fixture.journey.starts, 0);
    expect(fixture.journey.resumes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy non-audio history opens its route directory entry',
      (tester) async {
    final fixture = _Harness(context: _context(_legacyRoute));
    final router = await _pump(tester, fixture: fixture, userId: 'user-a');

    expect(router.routeInformationProvider.value.uri.path,
        '/route/${_legacyRoute.slug}');
    expect(fixture.tour.starts, 0);
    expect(fixture.journey.starts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('anonymous stale journey link safely returns to companion',
      (tester) async {
    final fixture = _Harness();
    final router = await _pump(tester, fixture: fixture);

    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(router.routeInformationProvider.value.uri.queryParameters['tab'],
        'companion');
    expect(fixture.lookups, isEmpty);
    expect(fixture.tour.starts, 0);
    expect(fixture.journey.starts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable history fails safely without starting a new journey',
      (tester) async {
    final fixture = _Harness();
    final router = await _pump(tester, fixture: fixture, userId: 'user-a');

    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(router.routeInformationProvider.value.uri.queryParameters['tab'],
        'companion');
    expect(fixture.lookups, [const UserJourneyKey('user-a', 'journey-a')]);
    expect(fixture.tour.starts, 0);
    expect(fixture.journey.starts, 0);
    expect(tester.takeException(), isNull);
  });
}

Future<GoRouter> _pump(WidgetTester tester,
    {required _Harness fixture, String? userId}) async {
  final router = GoRouter(
    initialLocation: '/journey/journey-a',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) => Scaffold(body: Text('home:${state.uri}')),
      ),
      GoRoute(
        path: '/route/:slug',
        builder: (_, state) =>
            Scaffold(body: Text('route:${state.pathParameters['slug']}')),
      ),
      GoRoute(
        path: '/journey/:id',
        builder: (_, state) =>
            JourneyRedirectPage(journeyId: state.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      activeTourControllerProvider.overrideWith(() => fixture.tour),
      journeyControllerProvider.overrideWith(() => fixture.journey),
      journeyContextProvider.overrideWith((ref, key) async {
        fixture.lookups.add(key);
        if (fixture.context == null) throw StateError('Journey unavailable');
        return fixture.context!;
      }),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return router;
}

class _Harness {
  _Harness({
    ActiveTourState active = const ActiveTourState(),
    JourneyUiState journey = const JourneyUiState(),
    this.context,
  })  : tour = _RecordingTour(active),
        journey = _RecordingJourney(journey);

  final _RecordingTour tour;
  final _RecordingJourney journey;
  final JourneyContext? context;
  final lookups = <UserJourneyKey>[];
}

class _RecordingTour extends ActiveTourController {
  _RecordingTour(this.initial);
  final ActiveTourState initial;
  var starts = 0;
  var stops = 0;
  ActiveTourState get snapshot => state;
  @override
  ActiveTourState build() => initial;
  @override
  Future<void> start(RouteExperience route, JourneySession session) async {
    starts++;
  }

  @override
  Future<void> stopTour() async {
    stops++;
  }
}

class _RecordingJourney extends JourneyController {
  _RecordingJourney(this.initial);
  final JourneyUiState initial;
  var starts = 0;
  var resumes = 0;
  JourneyUiState get snapshot => state;
  @override
  JourneyUiState build() => initial;
  @override
  Future<String?> start(RouteExperience route) async {
    starts++;
    return null;
  }

  @override
  String resume(RouteExperience route, JourneySession session) {
    resumes++;
    return super.resume(route, session);
  }
}

JourneyContext _context(RouteExperience route) => JourneyContext(
      journey: _session,
      route: route,
      journeyKind: route.audioTour == null ? 'legacy' : 'fragmented',
      collectedCount: 1,
      totalCount: 2,
    );

const _session = JourneySession(
  id: 'journey-a',
  routeId: 'route-a',
  status: 'active',
  currentStopPosition: 1,
  arrivedStopId: null,
  answeredStopIds: {},
  progress: .5,
);
const _otherSession = JourneySession(
  id: 'journey-other',
  routeId: 'route-other',
  status: 'active',
  currentStopPosition: 1,
  arrivedStopId: null,
  answeredStopIds: {},
  progress: .5,
);
final _audioRoute = _route('route-a', audio: true);
final _legacyRoute = _route('route-a', audio: false);
final _otherRoute = _route('route-other', audio: true);
RouteExperience _route(String id, {required bool audio}) => RouteExperience(
      id: id,
      slug: id,
      title: id,
      subtitle: '历史旅程',
      description: '测试用路线',
      durationMinutes: 45,
      distanceKm: 2.1,
      difficulty: '轻松',
      theme: '街区',
      heroImage: '',
      contentStatus: 'published',
      stops: const [],
      audioTour: audio ? _manifest : null,
    );
const _manifest = AudioTourManifest(
  title: '声音路线',
  centralQuestion: '听见什么？',
  scriptVersion: 'v1',
  reviewState: 'approved',
  fieldAuditState: 'approved',
  productionReady: true,
  demoLabel: null,
  contentMethod: 'field',
  downloadSizeBytes: 1,
  fragments: [_fragment],
);

const _fragment = StoryFragment(
  id: 'fragment-a',
  position: 1,
  safePreview: '旧街角的故事',
  interactionType: 'listen',
  reviewState: 'approved',
  triggerRegion: TriggerRegion(
    latitude: 22.54,
    longitude: 114.05,
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
    scriptVersion: 'v1',
  ),
);
