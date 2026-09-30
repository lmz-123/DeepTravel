import 'dart:io';
import 'dart:ui' show ImageByteFormat, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/core/router/travel_destinations.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/application/nearby_story_points.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/companion_distance_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_controller.dart';
import 'package:jiandi/features/experience/presentation/discovery_page.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/location_mode_controller.dart';
import 'package:jiandi/features/experience/presentation/offline_package_controller.dart';

/// Companion regression coverage is deliberately kept separate from release
/// approval. The tests assert the native phone surface size, keep labeled
/// 390×844 and 360×800 fixtures, and exercise the interaction state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    testWidgets(
        'distance target matches editorial preview at ${size.width.toInt()}px',
        (tester) async {
      final harness = _distanceHarness();
      await _pump(tester, harness: harness, size: size);
      expect(tester.takeException(), isNull);
      expect(_distancePlace(tester), '南城门');
      expect(_distanceNumber(tester), '120');
      expect(find.text('自动发现 · 最近未探索'), findsOneWidget);
      await _captureDistance(tester, 'auto', size.width.toInt());

      await _selectDistancePlace(tester, 'dongguan-hall',
          beforeSelection: () async {
        final picker = find.byKey(const ValueKey('companion-point-picker'));
        expect(tester.getTopLeft(picker).dy,
            closeTo(size.width <= 375 ? 45 : 58, 1));
        await _captureDistance(tester, 'picker', size.width.toInt());
      });
      expect(_distancePlace(tester), '东莞会馆');
      expect(_distanceNumber(tester), '260');
      expect(find.text('手动选定 · 距离目标'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SnackBar), findsNothing);
      await _captureDistance(tester, 'manual', size.width.toInt());
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(180);
      await tester.pump();
      await _captureDistance(tester, 'actions', size.width.toInt());
      expect(harness.tour.startCalls, 0);
      expect(harness.tour.playCalls, 0);
      expect(harness.tour.stopCalls, 0);
    });
  }

  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('walk actions stay on one row at $width with larger text',
        (tester) async {
      await _pump(tester,
          harness: _distanceHarness(), size: Size(width, 844), textScale: 1.3);
      final actions = find.byKey(const ValueKey('companion-walk-actions'));
      await _reveal(tester, actions);
      final primary =
          tester.getRect(find.byKey(const ValueKey('companion-primary')));
      final end = tester.getRect(find.byKey(const ValueKey('companion-end')));
      expect(primary.center.dy, closeTo(end.center.dy, .1));
      expect(primary.right, lessThan(end.left));
      expect(end.right, lessThanOrEqualTo(width - 20));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('choosing distance target leaves the current narration intact',
      (tester) async {
    final harness = _distanceHarness(playing: true);
    await _pump(tester, harness: harness);
    final before = harness.tour.snapshot;
    expect(_distancePlace(tester), '南城门');

    await _selectDistancePlace(tester, 'dongguan-hall');
    expect(_distancePlace(tester), '东莞会馆');
    expect(_distanceNumber(tester), '260');
    expect(harness.tour.snapshot, same(before));
    expect(harness.tour.snapshot.position, const Duration(seconds: 37));
    expect(harness.tour.snapshot.isPlaying, isTrue);
    expect(harness.tour.snapshot.selectedFragmentId, 'south-street');

    final automatic =
        find.byKey(const ValueKey('companion-distance-automatic'));
    await _reveal(tester, automatic);
    await tester.tap(automatic);
    await tester.pump();
    expect(_distancePlace(tester), '南城门');
    expect(_distanceNumber(tester), '120');
    expect(harness.tour.snapshot, same(before));
    expect(harness.tour.playCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual distance survives navigation and clears when walk ends',
      (tester) async {
    final harness = _distanceHarness();
    final router = await _pump(tester, harness: harness);
    await _selectDistancePlace(tester, 'dongguan-hall');
    router.push('/route/${_distanceRoute.slug}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_distancePlace(tester), '东莞会馆');
    expect(_distanceNumber(tester), '260');

    await _reveal(tester, find.text('结束本次随行'));
    await tester.tap(find.text('结束本次随行'));
    await tester.pump();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(DiscoveryPage)));
    expect(
      container
          .read(companionDistanceControllerProvider(_distanceRoute.slug))
          .mode,
      CompanionDistanceMode.automatic,
    );
    expect(harness.tour.stopCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit requested route changes clear the old distance target',
      (tester) async {
    final other = _route('another-route', '另一条路线');
    final harness = _CompanionHarness(routes: [_distanceRoute, other]);
    final router = await _pump(tester,
        harness: harness, requestedSlug: _distanceRoute.slug);
    await _selectDistancePlace(tester, 'dongguan-hall');
    expect(_distancePlace(tester), '东莞会馆');

    router.go(companionLocation(other.slug, requestSelection: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    router.go(companionLocation(_distanceRoute.slug, requestSelection: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('自动发现 · 最近未探索'), findsOneWidget);
    expect(_distancePlace(tester), '等待位置');
    expect(harness.tour.startCalls, 0);
    expect(harness.tour.playCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slow route handoff clears target even when its panel unmounts',
      (tester) async {
    final other = _route('slow-route', '另一条路线');
    final harness = _CompanionHarness(
      routes: [_distanceRoute, other],
      routeLoadDelays: {other.slug: const Duration(seconds: 2)},
    );
    final router = await _pump(tester,
        harness: harness, requestedSlug: _distanceRoute.slug);
    await _selectDistancePlace(tester, 'dongguan-hall');
    expect(_distancePlace(tester), '东莞会馆');

    router.go(companionLocation(other.slug, requestSelection: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        find.byKey(const ValueKey('companion-distance-target')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('本次随行 · 另一条路线'), findsOneWidget);

    router.go(companionLocation(_distanceRoute.slug, requestSelection: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('自动发现 · 最近未探索'), findsOneWidget);
    expect(_distancePlace(tester), '等待位置');
    expect(harness.tour.startCalls, 0);
    expect(harness.tour.playCalls, 0);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('preparing and cancelling never starts GPS or a journey',
      (tester) async {
    final harness = _CompanionHarness();
    await _pump(tester, harness: harness);
    await _reveal(tester, find.byKey(const ValueKey('companion-primary')));
    await tester.tap(find.byKey(const ValueKey('companion-primary')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('companion-walk-settings-sheet')),
        findsOneWidget);
    expect(harness.journey.startCalls, 0);
    expect(harness.tour.startCalls, 0);
    expect(find.byTooltip('关闭行走设置').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('关闭行走设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(harness.journey.startCalls, 0);
    expect(harness.tour.startCalls, 0);
    expect(harness.discovery.coldStartCalls, 0);
    expect(find.byKey(const ValueKey('companion-walk-settings-sheet')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the fifth requested route is selected before explicit start',
      (tester) async {
    final routes = List.generate(6, (i) => _route('route-$i', '测试路线 $i'));
    final harness = _CompanionHarness(routes: routes);
    await _pump(tester, harness: harness, requestedSlug: 'route-4');

    expect(find.text('本次随行 · 测试路线 4'), findsOneWidget);
    expect(harness.journey.startCalls, 0);
    expect(harness.tour.startCalls, 0);
    await _reveal(tester, find.byKey(const ValueKey('companion-primary')));
    await tester.tap(find.byKey(const ValueKey('companion-primary')));
    await _confirmStart(tester);
    expect(harness.tour.snapshot.route?.id, 'route-4');
    expect(harness.journey.startCalls, 1);
    expect(harness.tour.startCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cross-city handoff retains the requested route outside catalog',
      (tester) async {
    final requested = _route('another-city', '另一座城的旅程');
    final harness = _CompanionHarness(requestedRoute: requested);
    await _pump(tester, harness: harness, requestedSlug: requested.slug);

    expect(find.text('本次随行 · 另一座城的旅程'), findsOneWidget);
    expect(harness.journey.startCalls, 0);
    expect(harness.tour.startCalls, 0);
    expect(harness.discovery.coldStartCalls, 0);
    await _reveal(tester, find.byKey(const ValueKey('companion-primary')));
    await tester.tap(find.byKey(const ValueKey('companion-primary')));
    await _confirmStart(tester);
    expect(harness.tour.snapshot.route?.id, requested.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning from the same route detail renews its selection',
      (tester) async {
    final harness = _CompanionHarness();
    final router = await _pump(tester,
        harness: harness, requestedSlug: _routes.first.slug);
    final firstRequest =
        router.routeInformationProvider.value.uri.queryParameters['selection'];
    final originalPage = tester.state(find.byType(DiscoveryPage));
    expect(find.text('本次随行 · 测试路线 0'), findsOneWidget);

    final second = find.byKey(const ValueKey('companion-route-route-1'));
    await _reveal(tester, second);
    await tester.tap(second);
    await tester.pump();
    expect(find.text('本次随行 · 测试路线 1'), findsOneWidget);

    router.push('/route/${_routes.first.slug}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('detail:route-0'), findsOneWidget);
    await tester.tap(find.text('去随行'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(tester.state(find.byType(DiscoveryPage)), same(originalPage));
    expect(router.routeInformationProvider.value.uri.queryParameters['route'],
        _routes.first.slug);
    expect(
        router.routeInformationProvider.value.uri.queryParameters['selection'],
        isNot(firstRequest));
    expect(find.text('本次随行 · 测试路线 0'), findsOneWidget);
    expect(find.text('本次随行 · 测试路线 1'), findsNothing);
    expect(harness.journey.startCalls, 0);
    expect(harness.tour.startCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed route handoff never silently chooses the first route',
      (tester) async {
    final harness = _CompanionHarness();
    await _pump(tester, harness: harness, requestedSlug: 'missing-route');
    expect(find.text('这条路线暂时未能载入。'), findsOneWidget);
    expect(find.text('重新载入'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('companion-selected-route')), findsNothing);
    expect(harness.journey.startCalls, 0);
    expect(harness.tour.startCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('handoff while walking preserves session and listening progress',
      (tester) async {
    final initial = ActiveTourState(
      status: 'paused',
      route: _routes.first,
      session: _session(_routes.first),
      current: _fragment,
      position: const Duration(seconds: 37),
      selectedFragmentId: _fragment.id,
      locationMode: TourLocationMode.simulated,
    );
    final requested = _route('another-city', '另一座城的旅程');
    final harness = _CompanionHarness(
      initialTour: initial,
      requestedRoute: requested,
    );
    final router = await _pump(tester, harness: harness);
    router.go('/?tab=companion&route=${requested.slug}');
    await tester.pump(const Duration(milliseconds: 400));

    expect(harness.tour.snapshot, same(initial));
    expect(harness.tour.snapshot.position, const Duration(seconds: 37));
    expect(harness.tour.snapshot.session?.id, 'session-route-0');
    expect(harness.tour.startCalls, 0);
    expect(harness.tour.stopCalls, 0);
    expect(harness.journey.startCalls, 0);
    expect(find.text('继续寻找'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting disables repeated taps while preparing',
      (tester) async {
    final harness = _CompanionHarness(startDelay: const Duration(seconds: 2));
    await _pump(tester, harness: harness);

    final primary = find.byKey(const ValueKey('companion-primary'));
    await _reveal(tester, primary);
    await tester.tap(primary);
    await tester.pump();
    expect(harness.journey.startCalls, 0);
    expect(harness.tour.startCalls, 0);
    await _confirmStart(tester);
    expect(find.text('准备中…'), findsOneWidget);

    await _reveal(tester, primary);
    await tester.tap(primary);
    expect(harness.journey.startCalls, 1);
    expect(harness.tour.startCalls, 1);

    await tester.pump(const Duration(seconds: 3));
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
    await _confirmStart(tester);
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
    expect(find.byTooltip('暂停讲述'), findsOneWidget);
    expect(harness.tour.playCalls, 1);

    await _reveal(tester, find.byTooltip('暂停讲述'));
    await tester.tap(find.byTooltip('暂停讲述'));
    await tester.pump();
    expect(harness.tour.snapshot.isPlaying, isFalse);
    expect(harness.tour.snapshot.status, 'simulated');
    expect(find.text('播放这一段'), findsOneWidget);
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
    await _confirmStart(tester);
    expect(find.text('暂停随行'), findsOneWidget);

    await _reveal(tester, find.text('结束本次随行'));
    await tester.tap(find.text('结束本次随行'));
    await tester.pump();
    expect(find.text('开启随行'), findsOneWidget);
    expect(find.text('等你开启'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  _CompanionHarness? harness,
  String? requestedSlug,
  double textScale = 1,
}) async {
  final fixture = harness ?? _CompanionHarness();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: companionLocation(requestedSlug,
        requestSelection: requestedSlug != null),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) => DiscoveryPage(
          initialTab: state.uri.queryParameters['tab'],
          initialCompanionRouteSlug: state.uri.queryParameters['route'],
          initialCompanionRequestId: state.uri.queryParameters['selection'],
        ),
      ),
      GoRoute(
        path: '/route/:slug',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              Text('detail:${state.pathParameters['slug']}'),
              TextButton(
                onPressed: () => context.go(companionLocation(
                    state.pathParameters['slug'],
                    requestSelection: true)),
                child: const Text('去随行'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(null),
        companionDistanceNowProvider.overrideWithValue(() => _distanceNow),
        discoveryControllerProvider.overrideWith(() => fixture.discovery),
        offlineAwareRouteProvider.overrideWith((ref, slug) async {
          final delay = fixture.routeLoadDelays[slug];
          if (delay != null) await Future<void>.delayed(delay);
          final route = [
            ...fixture.discovery.routes,
            if (fixture.requestedRoute != null) fixture.requestedRoute!,
          ].where((route) => route.slug == slug).firstOrNull;
          if (route == null) throw StateError('Route unavailable');
          return route;
        }),
        locationModeControllerProvider.overrideWith(_MemoryMode.new),
        offlinePackageControllerProvider.overrideWith2(_NoOfflineIO.new),
        journeyControllerProvider.overrideWith(() => fixture.journey),
        activeTourControllerProvider.overrideWith(() => fixture.tour),
      ],
      child: RepaintBoundary(
        key: const ValueKey('companion-screen'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  // Allow asynchronous route providers to finish before interacting.
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
  return router;
}

Future<void> _confirmStart(WidgetTester tester) async {
  // The first frame mounts the bottom sheet and starts its entrance animation.
  // Advancing time before that frame leaves it below the phone viewport.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final done = find.byKey(const ValueKey('companion-settings-done'));
  await tester.ensureVisible(done);
  await tester.pump(const Duration(milliseconds: 50));
  expect(done.hitTestable(), findsOneWidget);
  await tester.tap(done);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    280,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(milliseconds: 50));
}

String? _distancePlace(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('companion-distance-place')))
    .data;

String? _distanceNumber(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('companion-distance-number')))
    .data;

Future<void> _selectDistancePlace(WidgetTester tester, String id,
    {Future<void> Function()? beforeSelection}) async {
  final target = find.byKey(const ValueKey('companion-distance-target'));
  if (target.hitTestable().evaluate().isEmpty) {
    await _reveal(tester, target);
  }
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const ValueKey('companion-point-picker')), findsOneWidget);
  await beforeSelection?.call();
  final place = find.byKey(ValueKey('companion-point-$id'));
  await tester.ensureVisible(place);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(place);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const ValueKey('companion-point-picker')), findsNothing);
}

Future<void> _captureDistance(
    WidgetTester tester, String mode, int width) async {
  final name = 'companion-distance-$mode-$width';
  final finder = find.byKey(const ValueKey('companion-screen'));
  if (mode != 'picker' && mode != 'actions') {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
  }
  await tester.pump();
  await expectLater(finder, matchesGoldenFile('goldens/$name.png'));
  const directory = String.fromEnvironment('COMPANION_EVIDENCE_DIR');
  if (directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

class _CompanionHarness {
  _CompanionHarness({
    this.startDelay = Duration.zero,
    List<RouteExperience>? routes,
    this.requestedRoute,
    this.routeLoadDelays = const {},
    CityExperience city = _city,
    ActiveTourState initialTour = const ActiveTourState(),
  })  : journey = _TestJourney(),
        tour = _TestTour(startDelay: startDelay, initial: initialTour),
        discovery = _TestDiscovery(routes ?? _routes, city: city);

  final Duration startDelay;
  final RouteExperience? requestedRoute;
  final Map<String, Duration> routeLoadDelays;
  final _TestJourney journey;
  final _TestTour tour;
  final _TestDiscovery discovery;
}

class _MemoryMode extends LocationModeController {
  @override
  Future<TourLocationMode> build() async => TourLocationMode.simulated;

  @override
  Future<void> setMode(TourLocationMode mode) async => state = AsyncData(mode);
}

class _NoOfflineIO extends OfflinePackageController {
  _NoOfflineIO(super.key);

  @override
  Future<OfflinePackageStatus> build() async =>
      const OfflinePackageStatus.idle();
}

JourneySession _session(RouteExperience route) => JourneySession(
      id: 'session-${route.id}',
      routeId: route.id,
      status: 'active',
      currentStopPosition: 1,
      arrivedStopId: null,
      answeredStopIds: const {},
      progress: 0,
    );

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
  _TestTour({
    this.startDelay = Duration.zero,
    this.initial = const ActiveTourState(),
  });

  final ActiveTourState initial;
  ActiveTourState get snapshot => state;

  final Duration startDelay;
  var startCalls = 0;
  var playCalls = 0;
  var stopCalls = 0;

  @override
  ActiveTourState build() => initial;

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
    stopCalls += 1;
    state = const ActiveTourState();
  }
}

class _TestDiscovery extends DiscoveryController {
  _TestDiscovery(this.routes, {this.city = _city});
  final List<RouteExperience> routes;
  final CityExperience city;
  var coldStartCalls = 0;

  @override
  Future<DiscoveryState> build() async => DiscoveryState(
        cities: [city],
        city: city,
        catalog: CityDiscoveryCatalog(routes: routes),
        cards: routes.map((route) => ScenicAreaCard(route: route)).toList(),
        revision: 0,
      );

  @override
  Future<DiscoveryStartupAction> prepareColdStart() async {
    coldStartCalls += 1;
    return DiscoveryStartupAction.completed;
  }
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

final _distanceNow = DateTime.utc(2026, 9, 30, 12);

const _distanceCity = CityExperience(
  id: 'shenzhen',
  slug: 'shenzhen',
  name: '深圳',
  subtitle: '',
  heroImage: '',
);

final _distancePlaces = <({String id, String name, int distance, bool heard})>[
  (id: 'south-gate', name: '南城门', distance: 120, heard: false),
  (id: 'south-street', name: '中山南街', distance: 45, heard: true),
  (id: 'dongguan-hall', name: '东莞会馆', distance: 260, heard: false),
  (id: 'guandi-temple', name: '关帝庙', distance: 270, heard: true),
  (id: 'county-office', name: '新安县衙', distance: 390, heard: false),
  (id: 'baode-square', name: '报德广场', distance: 510, heard: true),
  (id: 'ancient-museum', name: '南头古城博物馆', distance: 620, heard: false),
  (id: 'shenzhen-street', name: '绅缙街', distance: 730, heard: false),
  (id: 'north-gate', name: '北城门', distance: 860, heard: false),
  (id: 'jiujie', name: '九街', distance: 960, heard: true),
  (id: 'old-wall', name: '古城墙遗址', distance: 1120, heard: false),
  (id: 'juxiu', name: '聚秀街', distance: 1260, heard: false),
];

final _distanceFragments = [
  for (final (index, place) in _distancePlaces.indexed)
    StoryFragment(
      id: place.id,
      position: index + 1,
      placeName: place.name,
      safePreview: '沿着城市，慢慢走。',
      interactionType: 'listen',
      reviewState: 'approved',
      triggerRegion: TriggerRegion(
        latitude: 22.54 + place.distance / 111194.92664455874,
        longitude: 113.92,
        entryRadiusM: 60,
        exitRadiusM: 90,
        maxAccuracyM: 50,
        qualifyingSamples: 2,
        sampleWindowSeconds: 15,
        cooldownSeconds: 120,
        auditState: 'approved',
      ),
      audio: _fragment.audio,
      title: place.heard ? '${place.name}的故事' : null,
      state: place.heard ? 'collected' : 'undiscovered',
    ),
];

final _distanceRoute = RouteExperience(
  id: 'nantou',
  slug: 'nantou',
  title: '南头古城',
  subtitle: '',
  description: '',
  durationMinutes: 60,
  distanceKm: 2,
  difficulty: '轻松',
  theme: '古城',
  heroImage: '',
  contentStatus: 'published',
  stops: const [],
  cityName: '深圳',
  citySlug: 'shenzhen',
  audioTour: AudioTourManifest(
    title: '南头古城',
    centralQuestion: '',
    scriptVersion: 'distance-preview',
    reviewState: 'approved',
    fieldAuditState: 'approved',
    productionReady: true,
    demoLabel: null,
    contentMethod: 'field',
    downloadSizeBytes: 1,
    fragments: _distanceFragments,
  ),
);

_CompanionHarness _distanceHarness({bool playing = false}) => _CompanionHarness(
      city: _distanceCity,
      routes: [_distanceRoute],
      initialTour: ActiveTourState(
        status: 'listening',
        route: _distanceRoute,
        session: _session(_distanceRoute),
        ledger: StoryLedger(
          centralQuestion: '',
          collectedCount: 4,
          totalCount: 12,
          reconstructionUnlocked: false,
          entries: _distanceFragments,
        ),
        current: playing ? _distanceFragments[1] : null,
        selectedFragmentId: playing ? _distanceFragments[1].id : null,
        position: playing ? const Duration(seconds: 37) : Duration.zero,
        isPlaying: playing,
        locationMode: TourLocationMode.real,
        latestLocationSample: LocationSample(
          latitude: 22.54,
          longitude: 113.92,
          accuracyM: 8,
          recordedAt: _distanceNow,
        ),
      ),
    );
