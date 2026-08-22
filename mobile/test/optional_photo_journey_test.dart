import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/journey_page.dart';

void main() {
  testWidgets('collected clue keeps optional photo invite and shooting guide',
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
    expect(find.textContaining('不拍也可以继续'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拍摄并检查线索'));
    await tester.pumpAndSettle();

    expect(find.text('先找到经典机位'), findsOneWidget);
    expect(find.text('老树旁不挡路的位置'), findsOneWidget);
    expect(find.text('面向城门'), findsOneWidget);
    expect(find.text('城门居中，留出街巷'), findsOneWidget);
    expect(find.text('稍后再拍'), findsOneWidget);

    await tester.tap(find.text('稍后再拍'));
    await tester.pumpAndSettle();
    expect(find.text('先找到经典机位'), findsNothing);
    expect(find.text('可选的现场留念'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('下一条线索（测试）'),
      find.byType(ListView),
      const Offset(0, -180),
    );
    expect(find.text('下一条线索（测试）'), findsOneWidget);
  });

  testWidgets('fragment rail exposes 48px collected replay and locked feedback',
      (tester) async {
    final controller = _StaticTourController(_railState);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeTourControllerProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(home: JourneyPage(journeyId: 'journey-rail')),
    ));
    await tester.pumpAndSettle();

    final collected = find.byTooltip('回听第 1 条线索');
    final locked = find.byTooltip('线索尚未解锁');
    expect(tester.getSize(collected), const Size(48, 48));
    expect(tester.getSize(locked), const Size(48, 48));
    expect(find.bySemanticsLabel('第 1 条线索，已解锁，当前行走进度'), findsOneWidget);

    await tester.tap(collected);
    await tester.pump();
    expect(controller.selectedFragmentId, 'fragment-photo');

    await tester.tap(locked);
    await tester.pump();
    expect(find.text('这条线索尚未解锁'), findsOneWidget);
  });
}

class _StaticTourController extends ActiveTourController {
  _StaticTourController(this.initial);

  final ActiveTourState initial;
  String? selectedFragmentId;

  @override
  ActiveTourState build() => initial;

  @override
  Future<bool> selectCollectedFragment(String fragmentId) async {
    selectedFragmentId = fragmentId;
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
