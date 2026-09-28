import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/domain/home_story.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/presentation/route_manual/chapter_focus.dart';
import 'package:jiandi/features/experience/presentation/route_manual/manual_chapter.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/home_story_controller.dart';
import 'package:jiandi/features/experience/presentation/home_story_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pictures = <String, Uint8List>{};
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final (family, file) in [
      ('Noto Serif SC', 'NotoSerifSC.ttf'),
      ('Noto Sans SC', 'NotoSansSC.ttf'),
      ('Inter', 'Inter.ttf'),
      ('Georgia', 'Gelasio.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(
            await File('assets/fonts/$file').readAsBytes())));
      if (family == 'Georgia') {
        loader.addFont(Future.value(ByteData.sublistView(
            await File('assets/fonts/Gelasio-Italic.ttf').readAsBytes())));
      }
      await loader.load();
    }
    pictures['nantou'] =
        await File('test/fixtures/discovery/nantou.jpg').readAsBytes();
  });
  for (final width in [390.0, 360.0]) {
    testWidgets('home story typography ${width.toInt()}', (tester) async {
      tester.view.physicalSize = Size(width, width == 390 ? 844 : 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(ProviderScope(
            overrides: [
              discoveryControllerProvider.overrideWith(_EmptyDiscovery.new),
              homeStoryPlaybackControllerProvider
                  .overrideWith(_StoryController.new),
            ],
            child: RepaintBoundary(
                key: const ValueKey('golden-story'),
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light,
                    home: const HomeStoryPage()))));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
            find.byKey(const ValueKey('golden-story')),
            matchesGoldenFile(
                'goldens/home-story-listen-${width.toInt()}.png'));
        await tester.ensureVisible(find.text('安静地读这一篇'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('安静地读这一篇'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(find.byKey(const ValueKey('golden-story')),
            matchesGoldenFile('goldens/home-story-read-${width.toInt()}.png'));
        const chapter = ManualChapter(
            id: 'fragment',
            number: 1,
            title: '一扇城门，留住一座城的来处',
            place: '南头古城 · 南城门',
            body: '走进南头古城，抬头看一眼老城门。街巷的尺度里，藏着这座城市漫长的日常。',
            image: 'https://fixture.test/nantou',
            duration: Duration(minutes: 3, seconds: 28),
            fragment: _fragment);
        await tester.pumpWidget(ProviderScope(
            key: const ValueKey('manual-provider'),
            child: RepaintBoundary(
                key: const ValueKey('golden-manual'),
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light,
                    home: Scaffold(
                        body: ManualChapterFocus(
                            route: _route,
                            chapter: chapter,
                            chapters: const [chapter],
                            mode: ManualChapterMode.audio,
                            onBack: () {},
                            onDirectory: () {},
                            onSelect: (_) {},
                            onRead: () {},
                            onListen: () {}))))));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(find.byKey(const ValueKey('golden-manual')),
            matchesGoldenFile('goldens/manual-listen-${width.toInt()}.png'));
      }, createHttpClient: (_) => _FixtureClient(pictures));
    });
  }
}

class _EmptyDiscovery extends DiscoveryController {
  @override
  Future<DiscoveryState> build() async => const DiscoveryState(
      cities: [],
      city: null,
      catalog: CityDiscoveryCatalog(routes: []),
      cards: [],
      revision: 0);
}

class _StoryController extends HomeStoryPlaybackController {
  @override
  HomeStoryPlaybackState build() => const HomeStoryPlaybackState(
      phase: HomeStoryPhase.ready,
      story: HomeStory(
          id: 'golden-story',
          arcId: 'arc',
          title: '一扇城门，\n留住一座城的来处',
          introduction: '走进南头古城，抬头看一眼老城门。街巷的尺度里，藏着这座城市漫长的日常。',
          coverImage: 'https://fixture.test/nantou',
          duration: Duration(minutes: 3, seconds: 28),
          transcript:
              '从城门下穿过时，脚步可以慢一点。\n\n石砖上的痕迹，与门外的车流并列在同一个画面里。这里曾是地方的行政中心，如今仍然住着、走着、生活着许多人。\n\n向前走，留意街巷的宽窄、窗沿的细节，以及店铺门口的小小停留。它们让一座古城的历史，不只存在于墙上的介绍。',
          audioUrl: '',
          cityName: '深圳',
          citySlug: 'shenzhen',
          routeTitle: '南头古城',
          routeSlug: 'nantou',
          narratorName: '见地讲述者',
          placeContext: '南头古城 · 南城门',
          observableDetail: '抬头看看门洞和城墙，留意砖石的新旧交界。'));
  @override
  Future<void> pause() async {}
  @override
  Future<void> load({String? citySlug, bool excludeCurrent = false}) async {}
}

class _FixtureClient extends Fake implements HttpClient {
  _FixtureClient(this.pictures);
  final Map<String, Uint8List> pictures;
  @override
  bool autoUncompress = false;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FixtureRequest(pictures[url.pathSegments.last]!);
}

class _FixtureRequest extends Fake implements HttpClientRequest {
  _FixtureRequest(this.bytes);
  final Uint8List bytes;
  @override
  final HttpHeaders headers = _FixtureHeaders();
  @override
  Future<HttpClientResponse> close() async => _FixtureResponse(bytes);
}

class _FixtureHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FixtureResponse extends Stream<List<int>> implements HttpClientResponse {
  _FixtureResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _fragment = StoryFragment(
    id: 'fragment',
    position: 1,
    safePreview: '街角的故事',
    title: '街角',
    transcript: '街角的文字',
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
        auditState: 'reviewed'),
    audio: NarrationAsset(
        url: 'https://original.example/audio.m4a',
        mimeType: 'audio/mp4',
        sizeBytes: 1,
        scriptVersion: 'v1'));
const _route = RouteExperience(
    id: 'route',
    slug: 'route',
    title: '城市手册',
    subtitle: '慢慢走',
    description: '看看街角',
    durationMinutes: 20,
    distanceKm: 1.2,
    difficulty: '轻松',
    theme: '历史',
    heroImage: '',
    contentStatus: 'published',
    stops: [],
    audioTour: AudioTourManifest(
        title: '城市手册',
        centralQuestion: '眼前的城',
        scriptVersion: 'v1',
        reviewState: 'reviewed',
        fieldAuditState: 'reviewed',
        productionReady: true,
        demoLabel: null,
        contentMethod: 'research',
        downloadSizeBytes: 1,
        fragments: [_fragment]));
