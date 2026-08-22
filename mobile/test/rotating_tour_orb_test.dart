import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/features/experience/data/user_preferences_repository.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/location_mode_controller.dart';
import 'package:jiandi/features/experience/presentation/widgets/rotating_tour_orb.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'orb drags without navigating, persists, clamps and taps to journey',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = UserPreferencesRepository();
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: Stack(children: [Text('发现页'), RotatingTourOrbOverlay()]),
        ),
      ),
      GoRoute(
        path: '/journey/:id',
        builder: (_, state) => Scaffold(
          body: Text('旅程 ${state.pathParameters['id']}'),
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-a'),
        userPreferencesRepositoryProvider.overrideWithValue(preferences),
        activeTourControllerProvider.overrideWith(
          () => _StaticTourController(_pausedState),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    final orb = find.bySemanticsLabel(RegExp('正在播放 测试路线'));
    expect(orb, findsOneWidget);
    expect(tester.getSize(orb), const Size(72, 72));

    await tester.drag(orb, const Offset(-500, -500));
    await tester.pumpAndSettle();
    expect(find.text('发现页'), findsOneWidget);
    final topLeft = tester.getTopLeft(orb);
    expect(topLeft.dx, greaterThanOrEqualTo(0));
    expect(topLeft.dy, greaterThanOrEqualTo(0));
    final saved = await preferences.readOrbPosition('user-a');
    expect(saved.x, lessThan(1));
    expect(saved.y, 0);

    await tester.tap(orb);
    await tester.pumpAndSettle();
    expect(find.text('旅程 journey-1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('paused/reduced-motion orb is static and exposes move actions',
      (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'traveler_preferences:user-a:orb_x': 1.4,
      'traveler_preferences:user-a:orb_y': .8,
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-a'),
        activeTourControllerProvider.overrideWith(
          () => _StaticTourController(
            _pausedState.copyWith(isPlaying: true),
          ),
        ),
      ],
      child: const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(320, 600),
            disableAnimations: true,
            padding: EdgeInsets.only(top: 24, bottom: 20),
          ),
          child: Scaffold(
            body: Stack(children: [RotatingTourOrbOverlay()]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final orb = find.bySemanticsLabel(RegExp('正在播放 测试路线'));
    final bounds = tester.getRect(orb);
    expect(bounds.right, lessThanOrEqualTo(320));
    expect(bounds.bottom, lessThanOrEqualTo(600));
    final semantics = tester.getSemantics(orb);
    expect(semantics.getSemanticsData().customSemanticsActionIds, isNotEmpty);
  });

  testWidgets('stopped owner does not render the home orb', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-a'),
        activeTourControllerProvider.overrideWith(
          () => _StaticTourController(_pausedState.copyWith(status: 'stopped')),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: RotatingTourOrbOverlay())),
    ));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('正在播放')), findsNothing);
  });
}

class _StaticTourController extends ActiveTourController {
  _StaticTourController(this.initial);

  final ActiveTourState initial;

  @override
  ActiveTourState build() => initial;
}

const _fragment = StoryFragment(
  id: 'fragment-1',
  position: 1,
  safePreview: '线索',
  interactionType: 'passive',
  reviewState: 'reviewed',
  triggerRegion: TriggerRegion(
    latitude: 22.5,
    longitude: 114,
    entryRadiusM: 50,
    exitRadiusM: 80,
    maxAccuracyM: 35,
    qualifyingSamples: 2,
    sampleWindowSeconds: 15,
    cooldownSeconds: 120,
    auditState: 'reviewed',
  ),
  audio: NarrationAsset(
    url: 'https://cdn.example.test/audio.m4a',
    mimeType: 'audio/mp4',
    sizeBytes: 1,
    scriptVersion: 'v1',
  ),
  title: '第一条线索',
  state: 'collected',
);

const _route = RouteExperience(
  id: 'route-1',
  slug: 'route-1',
  title: '测试路线',
  subtitle: '测试',
  description: '测试',
  durationMinutes: 10,
  distanceKm: 1,
  difficulty: '轻松',
  theme: '历史',
  heroImage: '',
  contentStatus: 'published',
  stops: [],
  audioTour: AudioTourManifest(
    title: '测试路线',
    centralQuestion: '为什么？',
    scriptVersion: 'v1',
    reviewState: 'reviewed',
    fieldAuditState: 'reviewed',
    productionReady: true,
    demoLabel: null,
    contentMethod: '测试',
    downloadSizeBytes: 1,
    fragments: [_fragment],
  ),
);

const _pausedState = ActiveTourState(
  status: 'paused',
  route: _route,
  session: JourneySession(
    id: 'journey-1',
    routeId: 'route-1',
    status: 'active',
    currentStopPosition: 1,
    arrivedStopId: null,
    answeredStopIds: {},
    progress: 0,
  ),
  ledger: StoryLedger(
    centralQuestion: '为什么？',
    collectedCount: 1,
    totalCount: 1,
    reconstructionUnlocked: false,
    entries: [_fragment],
  ),
  current: _fragment,
  liveFragmentId: 'fragment-1',
  selectedFragmentId: 'fragment-1',
  duration: Duration(minutes: 2),
  position: Duration(seconds: 30),
);
