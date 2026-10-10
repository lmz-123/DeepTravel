import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'fixtures/city_atlas/approved_routes.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/home_story.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/home_story_controller.dart';
import 'package:jiandi/features/experience/presentation/location_mode_controller.dart';
import 'package:jiandi/features/experience/presentation/offline_package_controller.dart';
import 'package:jiandi/features/experience/presentation/route_detail_page.dart';
import 'package:jiandi/features/experience/presentation/route_manual/chapter_directory.dart';
import 'package:jiandi/features/experience/presentation/route_manual/chapter_focus.dart';
import 'package:jiandi/features/experience/presentation/route_manual/chapter_prelude.dart';
import 'package:jiandi/features/experience/presentation/route_manual/manual_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  List<int>? photoBytes;
  setUpAll(() async {
    const photoPath = String.fromEnvironment('ROUTE_PHOTO_FIXTURE',
        defaultValue: 'test/fixtures/route/wukang.png');
    if (photoPath.isNotEmpty) photoBytes = await File(photoPath).readAsBytes();
    for (final entry in {
      'Noto Serif SC': 'NotoSerifSC.ttf',
      'Noto Sans SC': 'NotoSansSC.ttf',
      'Inter': 'Inter.ttf',
      'Georgia': 'Gelasio.ttf'
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load('assets/fonts/${entry.value}'));
      if (entry.key == 'Georgia') {
        loader.addFont(rootBundle.load('assets/fonts/Gelasio-Italic.ttf'));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('v6 approved scenic detail composition', (tester) async {
    final route =
        (await tester.runAsync(() => approvedRoutes(companion: true)))!.first;
    final bytes = (await tester.runAsync(
        () => File('test/fixtures/discovery/coast.jpg').readAsBytes()))!;
    tester.view.physicalSize = const Size(390, 989);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(null),
            offlineAwareRouteProvider.overrideWith((ref, slug) async => route),
            homeStoryPlaybackControllerProvider
                .overrideWith(_QuietPlayback.new),
            journeyControllerProvider.overrideWith(_NoFieldStart.new),
            manualSessionProvider.overrideWith2(_MemorySession.new),
          ],
          child: RepaintBoundary(
              key: const ValueKey('manual-evidence'),
              child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light,
                  home: RouteDetailPage(slug: route.slug)))));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(RouteDetailPage));
      await tester.runAsync(
          () => precacheImage(NetworkImage(route.heroImage), context));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('manual-evidence')),
          matchesGoldenFile('goldens/v6-detail-390.png'));
    }, createHttpClient: (_) => _PhotoClient(bytes));
  });
  for (final size in [const Size(390, 844), const Size(360, 800)]) {
    testWidgets(
        'route opens directory directly, remains quiet, and reading never starts field tour at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await HttpOverrides.runZoned(() async {
        final playback = _QuietPlayback();
        final field = _NoFieldStart();
        await tester.pumpWidget(ProviderScope(
            overrides: [
              currentUserIdProvider.overrideWithValue(null),
              offlineAwareRouteProvider
                  .overrideWith((ref, slug) async => _route),
              homeStoryPlaybackControllerProvider.overrideWith(() => playback),
              journeyControllerProvider.overrideWith(() => field),
              manualSessionProvider.overrideWith2(_MemorySession.new),
              offlinePackageControllerProvider.overrideWith2(_NoOfflineIO.new),
              locationModeControllerProvider.overrideWith(_RealMode.new),
            ],
            child: RepaintBoundary(
                key: const ValueKey('manual-evidence'),
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light,
                    home: const RouteDetailPage(slug: 'quiet-route')))));
        await tester.pumpAndSettle();
        if (photoBytes != null) {
          // Image decoding runs outside the widget test's fake clock. Waiting
          // for a frame alone can capture the initial empty image placeholder.
          final imageContext = tester.element(find.byType(RouteDetailPage));
          Object? imageError;
          await tester.runAsync(() => precacheImage(
                NetworkImage(_route.heroImage),
                imageContext,
                onError: (error, stack) => imageError = error,
              ));
          expect(imageError, isNull);
          await tester.pumpAndSettle();
        }
        expect(find.byKey(const ValueKey('route-companion-entry')),
            findsOneWidget);
        expect(find.text('开启随行'), findsNothing);
        expect(find.text('行走准备'), findsNothing);
        expect(find.text('定位发现 · 到点提醒'), findsNothing);
        await _capture(tester, 'route-cover-${size.width.toInt()}');
        await expectLater(
          find.byKey(const ValueKey('manual-evidence')),
          matchesGoldenFile(
              'goldens/route-companion-${size.width.toInt()}.png'),
        );
        await tester
            .ensureVisible(find.byKey(const ValueKey('route-directory-entry')));
        await tester.tap(find.byKey(const ValueKey('route-directory-entry')));
        await tester.pumpAndSettle();
        expect(find.byType(RouteChapterDirectory), findsOneWidget);
        expect(find.byType(ChapterPrelude), findsNothing);
        expect(playback.plays, 0);
        expect(field.starts, 0);
        await _capture(tester, 'route-directory-${size.width.toInt()}');
        await tester
            .tap(find.byKey(const ValueKey('directory-chapter-chapter-2')));
        await tester.pumpAndSettle();
        expect(find.byType(ChapterPrelude), findsOneWidget);
        expect(playback.plays, 0);
        await _capture(tester, 'route-prelude-${size.width.toInt()}');
        await tester.tap(find.byKey(const ValueKey('manual-read-chapter')));
        await tester.pumpAndSettle();
        expect(find.byType(ManualChapterFocus), findsOneWidget);
        expect(find.text('第二篇完整的城市文字。'), findsOneWidget);
        expect(playback.plays, 0);
        expect(field.starts, 0);
        await _capture(tester, 'route-reading-${size.width.toInt()}');
        expect(tester.takeException(), isNull);
      }, createHttpClient: (_) => _PhotoClient(photoBytes));
    });
  }
  testWidgets('editorial entry navigates without starting a journey or audio',
      (tester) async {
    final playback = _QuietPlayback();
    final field = _NoFieldStart();
    final router = GoRouter(initialLocation: '/route/quiet-route', routes: [
      GoRoute(
          path: '/route/:slug',
          builder: (_, __) => const RouteDetailPage(slug: 'quiet-route')),
      GoRoute(
          path: '/',
          builder: (_, state) =>
              Scaffold(body: Text('destination:${state.uri}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue(null),
      offlineAwareRouteProvider.overrideWith((ref, slug) async => _route),
      homeStoryPlaybackControllerProvider.overrideWith(() => playback),
      journeyControllerProvider.overrideWith(() => field),
      manualSessionProvider.overrideWith2(_MemorySession.new),
    ], child: MaterialApp.router(routerConfig: router, theme: AppTheme.light)));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('route-companion-entry')));
    await tester.tap(find.byKey(const ValueKey('route-companion-entry')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    final query = router.routeInformationProvider.value.uri.queryParameters;
    expect(query['tab'], 'companion');
    expect(query['route'], 'quiet-route');
    expect(query['selection'], isNotEmpty);
    expect(field.starts, 0);
    expect(playback.plays, 0);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('ROUTE_EVIDENCE_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('manual-evidence')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

class _MemorySession extends ManualSessionController {
  _MemorySession(super.routeId);
  @override
  Future<ManualReadingSession> build() async => const ManualReadingSession();
  @override
  Future<void> remember(String chapterId,
      {Duration? position, bool opened = false}) async {
    final value = state.asData?.value ?? const ManualReadingSession();
    state = AsyncData(ManualReadingSession(
        currentId: chapterId,
        visited: opened ? {...value.visited, chapterId} : value.visited,
        positions: position == null
            ? value.positions
            : {...value.positions, chapterId: position}));
  }
}

class _QuietPlayback extends HomeStoryPlaybackController {
  int plays = 0;
  @override
  HomeStoryPlaybackState build() => const HomeStoryPlaybackState();
  @override
  Future<void> pause() async {}
  @override
  Future<void> loadManualChapter(RouteExperience route, StoryFragment fragment,
      {required String coverImage,
      String place = '',
      String? preparedPath,
      Duration resumePosition = Duration.zero}) async {
    state = HomeStoryPlaybackState(
        source: ListeningSource.manualChapter,
        phase: HomeStoryPhase.ready,
        story: HomeStory(
            id: 'manual:${route.id}:${fragment.id}:v1',
            arcId: route.id,
            title: fragment.title!,
            introduction: fragment.safePreview,
            coverImage: coverImage,
            duration: const Duration(minutes: 1),
            transcript: fragment.transcript!,
            audioUrl: fragment.audio.url,
            cityName: '',
            citySlug: '',
            routeTitle: route.title,
            routeSlug: route.slug,
            narratorName: '见地'));
  }

  @override
  Future<void> play() async {
    plays++;
  }
}

class _NoFieldStart extends JourneyController {
  int starts = 0;
  @override
  Future<String?> start(RouteExperience route) async {
    starts++;
    return null;
  }
}

class _NoOfflineIO extends OfflinePackageController {
  _NoOfflineIO(super.key);
  @override
  Future<OfflinePackageStatus> build() async =>
      const OfflinePackageStatus.idle();
}

class _RealMode extends LocationModeController {
  @override
  Future<TourLocationMode> build() async => TourLocationMode.real;
}

const _route = RouteExperience(
    id: 'route-a',
    slug: 'quiet-route',
    title: '武康路 · 安福路',
    subtitle: '梧桐深处的上海',
    cityName: '上海',
    description: '沿着街巷慢慢走，让一幢建筑、一扇窗和一个转角，把城市的故事铺展开来。',
    durationMinutes: 60,
    distanceKm: 2.4,
    difficulty: '轻松',
    theme: '建筑与记忆',
    heroImage: 'https://fixture.example/wukang.png',
    contentStatus: 'published',
    stops: [],
    manualChapters: [_first, _second],
    audioTour: AudioTourManifest(
      title: '梧桐深处的上海',
      centralQuestion: '城市如何留下记忆？',
      scriptVersion: 'v1',
      reviewState: 'reviewed',
      fieldAuditState: 'reviewed',
      productionReady: true,
      demoLabel: '',
      contentMethod: 'field',
      downloadSizeBytes: 2,
      fragments: [_first, _second],
    ));
const _first = StoryFragment(
    id: 'chapter-1',
    position: 1,
    title: '从一幢房子读懂城市',
    transcript: '第一篇完整的城市文字。',
    safePreview: '从街角开始',
    interactionType: 'passive',
    reviewState: 'reviewed',
    triggerRegion: _region,
    audio: _audio,
    expectedDurationSeconds: 48);
const _second = StoryFragment(
    id: 'chapter-2',
    position: 2,
    title: '梧桐深处的生活',
    transcript: '第二篇完整的城市文字。',
    safePreview: '沿梧桐漫步',
    interactionType: 'passive',
    reviewState: 'reviewed',
    triggerRegion: _region,
    audio: _audio,
    expectedDurationSeconds: 49);
const _region = TriggerRegion(
    latitude: 22.5,
    longitude: 114,
    entryRadiusM: 50,
    exitRadiusM: 80,
    maxAccuracyM: 35,
    qualifyingSamples: 2,
    sampleWindowSeconds: 15,
    cooldownSeconds: 120,
    auditState: 'reviewed');
const _audio = NarrationAsset(
    url: 'https://original-bucket.example/narration.m4a',
    mimeType: 'audio/mp4',
    sizeBytes: 1,
    scriptVersion: 'v1');

// Optional local reference photograph is injected at the HTTP boundary only in
// screenshot runs. Production always uses the unchanged URL in route metadata.
class _PhotoClient extends Fake implements HttpClient {
  _PhotoClient(this.bytes);
  final List<int>? bytes;
  @override
  set autoUncompress(bool value) {}
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PhotoRequest(bytes);
}

class _PhotoRequest extends Fake implements HttpClientRequest {
  _PhotoRequest(this.bytes);
  final List<int>? bytes;
  @override
  Future<HttpClientResponse> close() async => _PhotoResponse(bytes);
}

class _PhotoResponse extends Stream<List<int>> implements HttpClientResponse {
  _PhotoResponse(this.bytes);
  final List<int>? bytes;
  @override
  int get statusCode => bytes == null ? 404 : 200;
  @override
  int get contentLength => bytes?.length ?? 0;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(bytes ?? <int>[]).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
