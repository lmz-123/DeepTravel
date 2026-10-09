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
import 'package:jiandi/features/experience/presentation/city_atlas.dart';
import 'package:jiandi/features/experience/presentation/widgets/traveler_bottom_navigation.dart';
import 'fixtures/city_atlas/approved_routes.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/city_story.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_page.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

/// Approved art fixtures are test-only. Production still reads every image URL
/// from the route API, and the rendering path under test remains Image.network.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pictures = <String, Uint8List>{};
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
        loader.addFont(Future.value(ByteData.sublistView(
          await File('assets/fonts/Gelasio-Italic.ttf').readAsBytes(),
        )));
      }
      await loader.load();
    }
    for (final name in ['coast', 'nantou']) {
      pictures[name] =
          await File('test/fixtures/discovery/$name.jpg').readAsBytes();
    }
  });
  for (final page in ['journal', 'map']) {
    testWidgets('v6 approved $page composition', (tester) async {
      final routes = (await tester.runAsync(approvedRoutes))!;
      tester.view.physicalSize = Size(390, page == 'journal' ? 892 : 843);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => page == 'journal'
                ? const DiscoveryPage()
                : Scaffold(
                    backgroundColor: AppColors.paper,
                    body: Stack(children: [
                      CityAtlas(
                          citySlug: 'shenzhen',
                          cityName: '深圳',
                          routes: routes,
                          saved: const {},
                          busyFavorites: const {},
                          onFavorite: (_) {},
                          onOpen: (_) {},
                          onBack: () {}),
                      Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: TravelerBottomNavigation(
                              editorial: true,
                              active: TravelerSection.journal,
                              onSelected: (_) {})),
                    ])))
      ]);
      addTearDown(router.dispose);
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(ProviderScope(
            overrides: [
              currentUserIdProvider.overrideWithValue(null),
              experienceRepositoryProvider
                  .overrideWithValue(_GoldenRepository()),
              discoveryControllerProvider.overrideWith(
                  () => _ApprovedDiscovery(routes.take(2).toList())),
              activeTourControllerProvider.overrideWith(_GoldenTour.new),
            ],
            child: RepaintBoundary(
                key: const ValueKey('golden-screen'),
                child: MaterialApp.router(
                    debugShowCheckedModeBanner: false,
                    routerConfig: router,
                    theme: AppTheme.light))));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final context = tester.element(find.byType(Scaffold).first);
          for (final route
              in routes.where((route) => route.heroImage.isNotEmpty)) {
            await precacheImage(NetworkImage(route.heroImage), context);
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(find.byKey(const ValueKey('golden-screen')),
            matchesGoldenFile('goldens/v6-$page-390.png'));
      }, createHttpClient: (_) => _FixtureClient(pictures));
    });
  }

  for (final width in [390.0, 360.0]) {
    for (final tab in ['journal', 'atlas', 'shelf']) {
      testWidgets('$tab approved typography ${width.toInt()}', (tester) async {
        final size = Size(width, width == 390 ? 844 : 800);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => DiscoveryPage(initialTab: tab),
            ),
          ],
        );
        addTearDown(router.dispose);
        await HttpOverrides.runZoned(() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                currentUserIdProvider.overrideWithValue('golden-reader'),
                experienceRepositoryProvider.overrideWithValue(
                  _GoldenRepository(),
                ),
                travelerFavoritesProvider.overrideWith(
                  (ref, id) async => _favorites,
                ),
                discoveryControllerProvider.overrideWith(_GoldenDiscovery.new),
                activeTourControllerProvider.overrideWith(_GoldenTour.new),
              ],
              child: RepaintBoundary(
                key: const ValueKey('golden-screen'),
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  routerConfig: router,
                  theme: AppTheme.light,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final context = tester.element(find.byType(DiscoveryPage));
            await Future.wait(_routes.map((route) =>
                precacheImage(NetworkImage(route.heroImage), context)));
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const ValueKey('golden-screen')),
            matchesGoldenFile('goldens/discovery-$tab-${width.toInt()}.png'),
          );
          const motionOutput = String.fromEnvironment('JOURNAL_MOTION_OUTPUT');
          if (motionOutput.isNotEmpty && tab == 'journal' && width == 390) {
            await _captureJournalMotion(tester, motionOutput);
          }
          if (tab == 'journal' && width == 390) {
            await _checkCollageKeyframes(tester);
          }
        }, createHttpClient: (_) => _FixtureClient(pictures));
      });
    }
  }
}

/// Lock the approved layering at early/middle/late positions in both directions.
/// Driving the real gesture also covers the full-width hit area and finger sync.
Future<void> _checkCollageKeyframes(WidgetTester tester) async {
  for (final direction in [1, -1]) {
    final gesture =
        await tester.startGesture(Offset(direction > 0 ? 385 : 5, 390));
    var previous = 0.0;
    for (final progress in direction > 0 ? [.24, .48, .76] : [.48]) {
      await gesture
          .moveBy(Offset(-direction * (progress - previous) * 390 * .78, 0));
      previous = progress;
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(
        find.byKey(const ValueKey('golden-screen')),
        matchesGoldenFile(
            'goldens/discovery-collage-${direction > 0 ? 'next' : 'previous'}-${(progress * 100).round()}.png'),
      );
    }
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(find.text('大梅沙'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }
}

/// Optional real-widget filmstrip, using the same images and fonts as goldens.
/// flutter test --dart-define=JOURNAL_MOTION_OUTPUT=/tmp/journal-motion \
///   test/discovery_v5_golden_test.dart --plain-name "journal approved typography 390"
Future<void> _captureJournalMotion(WidgetTester tester, String output) async {
  final directory = Directory(output)..createSync(recursive: true);
  var frame = 0;
  Future<void> capture() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('golden-screen')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File(
        '${directory.path}/frame-${(frame++).toString().padLeft(3, '0')}.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  Future<void> frames(int count) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await capture();
    }
  }

  await frames(25);
  final gesture = await tester.startGesture(const Offset(285, 390));
  await gesture.moveBy(const Offset(-20, 0));
  for (var i = 0; i < 16; i++) {
    await gesture.moveBy(const Offset(-9, 0),
        timeStamp: Duration(milliseconds: (i + 1) * 20));
    await frames(1);
  }
  await gesture.up(timeStamp: const Duration(milliseconds: 360));
  await frames(50);
  await tester.tap(find.byTooltip('上一期随刊'));
  await frames(55);
  expect(find.text('大梅沙'), findsOneWidget);
  expect(tester.takeException(), isNull);
}

class _GoldenTour extends ActiveTourController {
  @override
  ActiveTourState build() => const ActiveTourState();
}

class _GoldenDiscovery extends DiscoveryController {
  @override
  Future<DiscoveryState> build() async => DiscoveryState(
        cities: const [_city],
        city: _city,
        catalog: const CityDiscoveryCatalog(routes: _routes),
        cards: _routes.map((r) => ScenicAreaCard(route: r)).toList(),
        revision: 0,
      );
  @override
  Future<DiscoveryStartupAction> prepareColdStart() async =>
      DiscoveryStartupAction.completed;
}

class _GoldenRepository extends DemoExperienceRepository {
  @override
  Future<List<CityExperience>> cities() async => [_city];
  @override
  Future<CityDiscoveryCatalog> discoveryForCity(String citySlug) async =>
      const CityDiscoveryCatalog(routes: _routes);
}

const _city = CityExperience(
  id: 'golden-shenzhen',
  slug: 'shenzhen',
  name: '深圳',
  subtitle: '向海，也向老街',
  heroImage: '',
);
const _routes = [
  RouteExperience(
    id: 'golden-coast',
    slug: 'coast',
    title: '大梅沙',
    subtitle: '把时间交给海风',
    description: '让海风带你重新认识这座城市。',
    durationMinutes: 50,
    distanceKm: 2.3,
    difficulty: '轻松',
    theme: '海边',
    district: '盐田区',
    heroImage: 'https://fixture.test/coast',
    contentStatus: 'published',
    stops: [],
    isFeatured: true,
  ),
  RouteExperience(
    id: 'golden-nantou',
    slug: 'nantou',
    title: '南头古城',
    subtitle: '旧街里，有新意',
    description: '拐进日常，遇见一座城的来处。',
    durationMinutes: 75,
    distanceKm: 1.8,
    difficulty: '轻松',
    theme: '老街',
    district: '南山区',
    heroImage: 'https://fixture.test/nantou',
    contentStatus: 'published',
    stops: [],
    isFeatured: true,
  ),
];
const _favorites = [
  TravelerFavorite(
    kind: 'route',
    targetId: 'golden-coast',
    available: true,
    label: '大梅沙',
  ),
  TravelerFavorite(
    kind: 'route',
    targetId: 'golden-nantou',
    available: true,
    label: '南头古城',
  ),
];

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

class _ApprovedDiscovery extends _GoldenDiscovery {
  _ApprovedDiscovery(this.routes);
  final List<RouteExperience> routes;
  @override
  Future<DiscoveryState> build() async => DiscoveryState(
      cities: const [_city],
      city: _city,
      catalog: CityDiscoveryCatalog(routes: routes),
      cards: routes.map((r) => ScenicAreaCard(route: r)).toList(),
      revision: 0);
}
