import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_page.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

void main() {
  testWidgets(
      'scenic card keeps the first point, backend tag, and no fake distance',
      (tester) async {
    await _pumpDiscovery(tester, journeyItem: null, context: null);

    expect(
        find.byKey(const ValueKey('scenic-card-fragment-a')), findsOneWidget);
    expect(find.text('第一条线索'), findsOneWidget);
    expect(find.text('安静'), findsOneWidget);
    expect(find.textContaining('距你'), findsNothing);
    final indicator = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('scenic-indicator-0')),
    );
    expect(indicator.constraints?.maxWidth, 24);
  });

  testWidgets(
      'purpose explanation appears before permission request and decline is usable',
      (tester) async {
    final controller = _PurposeDiscoveryController();
    await _pumpDiscovery(
      tester,
      journeyItem: null,
      context: null,
      discoveryController: controller,
    );

    expect(find.text('看看离你最近的见地'), findsOneWidget);
    expect(find.textContaining('不会持续追踪'), findsOneWidget);
    await tester.tap(find.text('手动选择城市'));
    await tester.pumpAndSettle();

    expect(controller.declined, isTrue);
    expect(find.byTooltip('选择城市'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('scenic-card-fragment-a')), findsOneWidget);
  });

  testWidgets('first visit still enters the headphone invitation',
      (tester) async {
    await _pumpDiscovery(tester, journeyItem: null, context: null);
    await tester.tap(find.byKey(const ValueKey('scenic-card-fragment-a')));
    await tester.pumpAndSettle();
    expect(find.text('headphone-gate'), findsOneWidget);
  });

  testWidgets('active route opens its existing journey directly',
      (tester) async {
    final ownerContext = _context(status: 'active', kind: 'fragmented');
    await _pumpDiscovery(
      tester,
      journeyItem: _item(ownerContext),
      context: ownerContext,
    );
    await tester.tap(find.byKey(const ValueKey('scenic-card-fragment-a')));
    await tester.pumpAndSettle();
    expect(find.text('journey-target'), findsOneWidget);
  });

  testWidgets('completed audio route bypasses gate and initializes revisit',
      (tester) async {
    final ownerContext = _context(status: 'completed', kind: 'fragmented');
    final controller = _RecordingRevisitController();
    await _pumpDiscovery(
      tester,
      journeyItem: _item(ownerContext),
      context: ownerContext,
      activeController: controller,
    );
    await tester.tap(find.byKey(const ValueKey('scenic-card-fragment-a')));
    await tester.pumpAndSettle();
    expect(find.text('journey-target'), findsOneWidget);
    expect(controller.revisitedJourneyId, 'journey-a');
  });

  testWidgets('completed legacy route opens footprint recap directly',
      (tester) async {
    final ownerContext = _context(status: 'completed', kind: 'legacy');
    await _pumpDiscovery(
      tester,
      journeyItem: _item(ownerContext),
      context: ownerContext,
    );
    await tester.tap(find.byKey(const ValueKey('scenic-card-fragment-a')));
    await tester.pumpAndSettle();
    expect(find.text('legacy-footprint'), findsOneWidget);
  });

  test('mixed history index keeps active journey ahead of completion',
      () async {
    final completed = _item(_context(status: 'completed', kind: 'fragmented'));
    final activeContext = _context(status: 'active', kind: 'fragmented');
    final active = JourneyLibraryItem(
      journey: JourneySession(
        id: 'journey-active',
        routeId: activeContext.route.id,
        status: 'active',
        currentStopPosition: 1,
        arrivedStopId: null,
        answeredStopIds: const {},
        progress: .4,
      ),
      route: activeContext.route,
      journeyKind: 'fragmented',
      collectedCount: 1,
      totalCount: 2,
      evidenceCount: 0,
    );
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('user-a'),
      currentAllJourneysProvider.overrideWith(
        (ref) async => [completed, active],
      ),
    ]);
    addTearDown(container.dispose);
    final index = await container.read(routeJourneyIndexProvider.future);
    expect(index['route-a']?.journey.id, 'journey-active');
  });
}

Future<void> _pumpDiscovery(
  WidgetTester tester, {
  required JourneyLibraryItem? journeyItem,
  required JourneyContext? context,
  _RecordingRevisitController? activeController,
  DiscoveryController? discoveryController,
}) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const DiscoveryPage()),
    GoRoute(
      path: '/route/:slug',
      builder: (_, __) => const Scaffold(body: Text('headphone-gate')),
    ),
    GoRoute(
      path: '/journey/:id',
      builder: (_, __) => const Scaffold(body: Text('journey-target')),
    ),
    GoRoute(
      path: '/footprints/:id',
      builder: (_, __) => const Scaffold(body: Text('legacy-footprint')),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('user-a'),
      discoveryControllerProvider.overrideWith(
        () => discoveryController ?? _FixedDiscoveryController(),
      ),
      archivedActiveJourneysProvider.overrideWith((ref) async => const []),
      routeJourneyIndexProvider.overrideWith(
        (ref) async => journeyItem == null
            ? const <String, JourneyLibraryItem>{}
            : {'route-a': journeyItem},
      ),
      journeyContextProvider.overrideWith((ref, key) async {
        if (context == null) throw StateError('unexpected context lookup');
        return context;
      }),
      activeTourControllerProvider.overrideWith(
        () => activeController ?? _RecordingRevisitController(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

class _RecordingRevisitController extends ActiveTourController {
  String? revisitedJourneyId;

  @override
  ActiveTourState build() => const ActiveTourState();

  @override
  Future<void> startRevisit(JourneyContext context) async {
    revisitedJourneyId = context.journey.id;
  }
}

class _FixedDiscoveryController extends DiscoveryController {
  @override
  Future<DiscoveryState> build() async => const DiscoveryState(
        cities: [_city],
        city: _city,
        catalog: CityDiscoveryCatalog(
          routes: [_route],
          scenicSpots: [_spot],
        ),
        cards: [ScenicSpotCard(spot: _spot, route: _route)],
        revision: 0,
      );

  @override
  Future<DiscoveryStartupAction> prepareColdStart() async =>
      DiscoveryStartupAction.completed;
}

class _PurposeDiscoveryController extends _FixedDiscoveryController {
  bool declined = false;

  @override
  Future<DiscoveryStartupAction> prepareColdStart() async =>
      DiscoveryStartupAction.needsPurposeExplanation;

  @override
  void declineColdStart() => declined = true;
}

const _city = CityExperience(
  id: 'city-a',
  slug: 'city-a',
  name: '测试城',
  subtitle: '测试',
  heroImage: '',
);

const _fragment = StoryFragment(
  id: 'fragment-a',
  position: 1,
  safePreview: '第一条线索',
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
    url: 'https://example.test/audio.m4a',
    mimeType: 'audio/mp4',
    sizeBytes: 1,
    scriptVersion: 'v1',
  ),
  title: '第一条线索',
  state: 'collected',
);

const _spot = ScenicSpot(
  id: 'fragment-a',
  title: '第一条线索',
  latitude: 22.5,
  longitude: 114,
  experienceTags: ['安静'],
  routeId: 'route-a',
);

const _route = RouteExperience(
  id: 'route-a',
  slug: 'route-a',
  title: '测试路线',
  subtitle: '测试',
  description: '路线描述',
  durationMinutes: 20,
  distanceKm: 1.2,
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

JourneyContext _context({required String status, required String kind}) =>
    JourneyContext(
      journey: JourneySession(
        id: 'journey-a',
        routeId: 'route-a',
        status: status,
        currentStopPosition: 1,
        arrivedStopId: null,
        answeredStopIds: const {},
        progress: status == 'completed' ? 1 : .4,
      ),
      route: _route,
      journeyKind: kind,
      collectedCount: 1,
      totalCount: 1,
      ledger: kind == 'fragmented'
          ? const StoryLedger(
              centralQuestion: '为什么？',
              collectedCount: 1,
              totalCount: 1,
              reconstructionUnlocked: true,
              entries: [_fragment],
            )
          : null,
    );

JourneyLibraryItem _item(JourneyContext context) => JourneyLibraryItem(
      journey: context.journey,
      route: context.route,
      journeyKind: context.journeyKind,
      collectedCount: context.collectedCount,
      totalCount: context.totalCount,
      evidenceCount: 0,
    );
