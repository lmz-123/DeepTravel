import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/journey_page.dart';

void main() {
  testWidgets('selected node exposes one optional photo entry and guide detail',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeTourControllerProvider.overrideWith(
          () => _StaticTourController(_photoState),
        ),
      ],
      child: const MaterialApp(home: JourneyPage(journeyId: 'journey-photo')),
    ));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('可选的现场留念'),
      find.byType(ListView),
      const Offset(0, -260),
    );
    expect(find.text('可选的现场留念'), findsOneWidget);
    expect(find.byKey(const ValueKey('node-photo-entry-fragment-photo')),
        findsOneWidget);
    expect(find.text('老树旁不挡路的位置'), findsNothing);

    await tester.tap(find.text('可选的现场留念'));
    await tester.pumpAndSettle();

    expect(find.text('推荐机位'), findsOneWidget);
    expect(find.text('老树旁不挡路的位置'), findsOneWidget);
    expect(find.text('面向城门'), findsOneWidget);
    expect(find.text('城门居中，留出街巷'), findsOneWidget);
    expect(find.text('打开相机'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭留念详情'));
    await tester.pumpAndSettle();
    expect(find.text('推荐机位'), findsNothing);
    expect(find.text('可选的现场留念'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('下一条线索（测试）'),
      find.byType(ListView),
      const Offset(0, -180),
    );
    expect(find.text('下一条线索（测试）'), findsOneWidget);
  });

  testWidgets('fragment rail keeps safe targets and selects every node',
      (tester) async {
    final controller = _StaticTourController(_railState);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeTourControllerProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(home: JourneyPage(journeyId: 'journey-rail')),
    ));
    await tester.pumpAndSettle();

    final collected = find.byTooltip('回听第 1 个节点');
    final untriggered = find.byTooltip('查看信息第 2 个节点');
    expect(tester.getSize(collected).width, inInclusiveRange(44, 56));
    expect(tester.getSize(untriggered).width, inInclusiveRange(44, 56));
    expect(
        find.bySemanticsLabel('第 1 个节点，城门的变化，已听过，当前行走进度，回听'), findsOneWidget);

    await tester.tap(collected);
    await tester.pump();
    expect(controller.selectedFragmentId, 'fragment-photo');

    await tester.tap(untriggered);
    await tester.pump();
    expect(controller.selectedFragmentId, 'fragment-locked');
    expect(find.byKey(const ValueKey('selected-node-detail-fragment-locked')),
        findsOneWidget);
    expect(find.text('尚未发现的线索'), findsOneWidget);
    expect(find.text('这条线索尚未解锁'), findsNothing);
    final detail =
        find.byKey(const ValueKey('selected-node-detail-fragment-locked'));
    final audio = find.byKey(const ValueKey('fragment-photo'));
    expect(
        tester.getBottomLeft(detail).dy, lessThan(tester.getTopLeft(audio).dy));
  });

  testWidgets(
      'dense rail renders an arbitrary backend node count without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fragments = List<StoryFragment>.generate(
      8,
      (index) => StoryFragment(
        id: 'dense-${index + 1}',
        position: index + 1,
        safePreview: '密集节点 ${index + 1}',
        interactionType: 'passive',
        reviewState: 'reviewed',
        triggerRegion: _region,
        audio: _photoFragment.audio,
      ),
    );
    final manifest = AudioTourManifest(
      title: '密集节点路线',
      centralQuestion: '多个节点如何展示？',
      scriptVersion: 'v1',
      reviewState: 'reviewed',
      fieldAuditState: 'reviewed',
      productionReady: true,
      demoLabel: null,
      contentMethod: '测试',
      downloadSizeBytes: 1,
      fragments: fragments,
    );
    final route = RouteExperience(
      id: 'dense-route',
      slug: 'dense-route',
      title: '密集节点路线',
      subtitle: '测试',
      description: '测试',
      durationMinutes: 20,
      distanceKm: 1,
      difficulty: '轻松',
      theme: '历史',
      heroImage: '',
      contentStatus: 'published',
      stops: const [],
      audioTour: manifest,
    );
    final state = ActiveTourState(
      status: 'monitoring',
      route: route,
      session: const JourneySession(
        id: 'dense-journey',
        routeId: 'dense-route',
        status: 'active',
        currentStopPosition: 1,
        arrivedStopId: null,
        answeredStopIds: {},
        progress: 0,
      ),
      ledger: StoryLedger(
        centralQuestion: '多个节点如何展示？',
        collectedCount: 0,
        totalCount: fragments.length,
        reconstructionUnlocked: false,
        entries: fragments,
      ),
      selectedFragmentId: 'dense-1',
      locationMode: TourLocationMode.real,
    );
    final controller = _StaticTourController(state);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeTourControllerProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(home: JourneyPage(journeyId: 'dense-journey')),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fragment-node-rail-scroll')),
        findsOneWidget);
    for (var position = 1; position <= 8; position += 1) {
      expect(find.byTooltip('查看信息第 $position 个节点'), findsOneWidget);
    }
    await tester.drag(
      find.byKey(const ValueKey('fragment-node-rail-scroll')),
      const Offset(-240, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('查看信息第 8 个节点'));
    await tester.pump();
    expect(controller.selectedFragmentId, 'dense-8');
    expect(find.text('密集节点 8'), findsOneWidget);
  });
}

class _StaticTourController extends ActiveTourController {
  _StaticTourController(this.initial);

  final ActiveTourState initial;
  String? selectedFragmentId;

  @override
  ActiveTourState build() => initial;

  @override
  Future<bool> selectNode(String fragmentId) async {
    selectedFragmentId = fragmentId;
    state = state.copyWith(selectedFragmentId: fragmentId);
    return true;
  }
}

const _region = TriggerRegion(
  latitude: 22.5,
  longitude: 114,
  entryRadiusM: 50,
  exitRadiusM: 80,
  maxAccuracyM: 35,
  qualifyingSamples: 2,
  sampleWindowSeconds: 15,
  cooldownSeconds: 120,
  auditState: 'reviewed',
);

const _photoFragment = StoryFragment(
  id: 'fragment-photo',
  position: 1,
  safePreview: '入口线索',
  interactionType: 'photo',
  reviewState: 'reviewed',
  triggerRegion: _region,
  audio: NarrationAsset(
    url: 'https://example.test/photo.m4a',
    mimeType: 'audio/mp4',
    sizeBytes: 1,
    scriptVersion: 'v1',
  ),
  title: '城门的变化',
  transcript: '已经听完的正文',
  state: 'collected',
  mission: PhotoMission(
    id: 'mission-1',
    prompt: '拍下城门和街巷的关系',
    fieldSubject: '城门',
    safetyCopy: '留在人行道内，避开车流',
    accessibilityAlternative: '可以跳过',
    authenticityLabel: '现场留念',
    required: false,
    auditState: 'reviewed',
    vantagePoint: '老树旁不挡路的位置',
    shootingDirection: '面向城门',
    compositionTip: '城门居中，留出街巷',
  ),
);

const _manifest = AudioTourManifest(
  title: '照片路线',
  centralQuestion: '城门如何变化？',
  scriptVersion: 'v1',
  reviewState: 'reviewed',
  fieldAuditState: 'reviewed',
  productionReady: true,
  demoLabel: null,
  contentMethod: '测试',
  downloadSizeBytes: 1,
  fragments: [_photoFragment],
);

const _route = RouteExperience(
  id: 'route-photo',
  slug: 'route-photo',
  title: '照片路线',
  subtitle: '测试',
  description: '测试',
  durationMinutes: 10,
  distanceKm: 1,
  difficulty: '轻松',
  theme: '历史',
  heroImage: '',
  contentStatus: 'published',
  stops: [],
  audioTour: _manifest,
);

const _photoState = ActiveTourState(
  status: 'simulated',
  route: _route,
  session: JourneySession(
    id: 'journey-photo',
    routeId: 'route-photo',
    status: 'active',
    currentStopPosition: 1,
    arrivedStopId: null,
    answeredStopIds: {},
    progress: 1,
  ),
  ledger: StoryLedger(
    centralQuestion: '城门如何变化？',
    collectedCount: 1,
    totalCount: 1,
    reconstructionUnlocked: false,
    entries: [_photoFragment],
  ),
  current: _photoFragment,
  liveFragmentId: 'fragment-photo',
  selectedFragmentId: 'fragment-photo',
  locationMode: TourLocationMode.simulated,
);

const _lockedFragment = StoryFragment(
  id: 'fragment-locked',
  position: 2,
  safePreview: '尚未发现的线索',
  interactionType: 'passive',
  reviewState: 'reviewed',
  triggerRegion: _region,
  audio: NarrationAsset(
    url: 'https://example.test/locked.m4a',
    mimeType: 'audio/mp4',
    sizeBytes: 1,
    scriptVersion: 'v1',
  ),
  dependencyIds: ['fragment-photo'],
);

const _railRoute = RouteExperience(
  id: 'route-rail',
  slug: 'route-rail',
  title: '节点路线',
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
    title: '节点路线',
    centralQuestion: '线索如何连接？',
    scriptVersion: 'v1',
    reviewState: 'reviewed',
    fieldAuditState: 'reviewed',
    productionReady: true,
    demoLabel: null,
    contentMethod: '测试',
    downloadSizeBytes: 1,
    fragments: [_photoFragment, _lockedFragment],
  ),
);

const _railState = ActiveTourState(
  status: 'simulated',
  route: _railRoute,
  session: JourneySession(
    id: 'journey-rail',
    routeId: 'route-rail',
    status: 'active',
    currentStopPosition: 1,
    arrivedStopId: null,
    answeredStopIds: {},
    progress: .5,
  ),
  ledger: StoryLedger(
    centralQuestion: '线索如何连接？',
    collectedCount: 1,
    totalCount: 2,
    reconstructionUnlocked: false,
    entries: [_photoFragment, _lockedFragment],
  ),
  current: _photoFragment,
  liveFragmentId: 'fragment-photo',
  selectedFragmentId: 'fragment-photo',
  locationMode: TourLocationMode.simulated,
);
