import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:jiandi/features/experience/data/prepared_route_service.dart';
import 'package:jiandi/features/experience/data/route_offline_package_service.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_page.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

void main() {
  testWidgets(
      'scenic-area card keeps route metadata, contains nodes, and has no fake distance',
      (tester) async {
    await _pumpDiscovery(tester, journeyItem: null, context: null);

    expect(find.byKey(const ValueKey('route-card-route-a')), findsOneWidget);
    expect(find.text('测试路线'), findsOneWidget);
    expect(find.text('第一条线索'), findsNothing);
    expect(find.textContaining('距你'), findsNothing);
    final indicator = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('route-indicator-0')),
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
    expect(find.byKey(const ValueKey('route-card-route-a')), findsOneWidget);
  });

  testWidgets('first visit still enters the headphone invitation',
      (tester) async {
    await _pumpDiscovery(tester, journeyItem: null, context: null);
    await _tapRouteCard(tester);
    await tester.pumpAndSettle();
    expect(find.text('headphone-gate'), findsOneWidget);
  });

  testWidgets('home scenic card keeps one clear manual entry', (tester) async {
    await _pumpDiscovery(
      tester,
      journeyItem: null,
      context: null,
      userId: null,
    );
    expect(find.byKey(const ValueKey('offline-package-route-a')), findsNothing);
    expect(find.text('打开城市手册 →'), findsOneWidget);
    expect(find.byKey(const ValueKey('route-card-route-a')), findsOneWidget);
  });

  testWidgets('active route opens its existing journey directly',
      (tester) async {
    final ownerContext = _context(status: 'active', kind: 'fragmented');
    await _pumpDiscovery(
      tester,
      journeyItem: _item(ownerContext),
      context: ownerContext,
    );
    await _tapRouteCard(tester);
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
    await _tapRouteCard(tester);
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
    await _tapRouteCard(tester);
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

Future<void> _tapRouteCard(WidgetTester tester) async {
  final card = find.byKey(const ValueKey('route-card-route-a'));
  await tester.ensureVisible(card);
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
  await tester.pumpAndSettle();
  await tester.tap(card);
}

Future<void> _pumpDiscovery(
  WidgetTester tester, {
  required JourneyLibraryItem? journeyItem,
  required JourneyContext? context,
  _RecordingRevisitController? activeController,
  DiscoveryController? discoveryController,
  RouteOfflinePackageService? offlineService,
  String? userId = 'user-a',
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
      currentUserIdProvider.overrideWithValue(userId),
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
      routeOfflinePackageServiceProvider.overrideWithValue(
        offlineService ?? _RecordingOfflinePackageService(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

class _RecordingOfflinePackageService extends RouteOfflinePackageService {
  _RecordingOfflinePackageService()
      : super(Dio(), _CardStore(), PreparedRouteService(Dio(), _CardStore()));

  String? installedSlug;

  @override
  Future<OfflinePackageStatus> status(
    String slug, {
    String? currentVersion,
  }) async =>
      const OfflinePackageStatus.idle();

  @override
  Future<InstalledRoutePackage> install(
    String slug, {
    String? preferredNarrationProfileId,
    void Function(int complete, int total)? onProgress,
  }) async {
    installedSlug = slug;
    onProgress?.call(1, 2);
    return const InstalledRoutePackage(
      city: _city,
      route: _route,
      version: 'v1',
      checksumSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      narrationProfileId: null,
      preparedPaths: {'fragment-a': '/cache/fragment-a.m4a'},
      raw: {},
    );
  }
}

class _CardStore implements TourStore {
  @override
  Future<void> acknowledge(String id) async {}
  @override
  Future<void> clearPrivateData() async {}
  @override
  Future<void> enqueue(OutboxEvent event) async {}
  @override
  Future<List<OutboxEvent>> pending() async => const [];
  @override
  Future<String?> preparedAsset(
          String url, String version, int sizeBytes) async =>
      null;
  @override
  Future<List<PreparedAssetRecord>> preparedAssets() async => const [];
  @override
  Future<void> removePreparedAsset(String url) async {}
  @override
  Future<Map<String, dynamic>?> readJson(String key) async => null;
  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {}
  @override
  Future<void> savePreparedAsset(
      String url, String path, String version, int sizeBytes) async {}
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
        ),
        cards: [ScenicAreaCard(route: _route)],
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
  centerLatitude: 22.5,
  centerLongitude: 114,
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
