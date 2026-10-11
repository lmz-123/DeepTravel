import 'package:jiandi/features/experience/presentation/places_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/presentation/city_atlas.dart';
import 'package:jiandi/features/experience/presentation/travel/ticket_page.dart';
import 'package:jiandi/features/experience/presentation/travel/preparation_page.dart';
import 'package:jiandi/features/experience/domain/travel_preparation.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'travel_preparation_test.dart' as fixture;
import 'city_atlas_test.dart' as places;

class _Launcher extends UrlLauncherPlatform {
  @override
  get linkDelegate => null;
  final calls = <String>[];
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls.add(url);
    return true;
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final e in {
      'Noto Serif SC': 'NotoSerifSC.ttf',
      'Noto Sans SC': 'NotoSansSC.ttf',
      'Georgia': 'Gelasio.ttf',
      'Inter': 'Inter.ttf'
    }.entries) {
      await (FontLoader(e.key)
            ..addFont(rootBundle.load('assets/fonts/${e.value}')))
          .load();
    }
  });
  for (final width in [320.0, 390.0]) {
    for (final screen in ['list', 'map', 'ticket', 'unknown-price', 'entry']) {
      testWidgets('$screen approved layout $width', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final launch = _Launcher();
        final previous = UrlLauncherPlatform.instance;
        UrlLauncherPlatform.instance = launch;
        addTearDown(() => UrlLauncherPlatform.instance = previous);
        final ticket = TicketOption({
          'title': '全日票',
          'subtitle': '白天入园 · 日夜通玩',
          'price': screen == 'unknown-price' ? '' : '220',
          'checked_at': DateTime.now().toUtc().toIso8601String(),
          'purchase_url': 'https://official.example/tickets/day',
          'audience': '成人及符合全价票条件的游客',
          'entry_time': '日间入园，可游玩至当日闭园。具体时段以所选日期的官方说明为准。',
          'refund_policy': '下单前请阅读官方订单页的退改说明。'
        });
        final Widget body = screen == 'entry'
            ? Scaffold(
                body: Padding(
                    padding: const EdgeInsets.all(23),
                    child: RoutePreparationEntry(route: fixture.sample())))
            : ['ticket', 'unknown-price'].contains(screen)
                ? TicketPage(route: fixture.sample(), ticket: ticket)
                : Scaffold(
                    body: CityAtlas(
                        citySlug: 'shenzhen',
                        cityName: '深圳',
                        routes: [
                          places.place('世界之窗'),
                          places.place('大梅沙'),
                          places.place('南头古城', theme: '街巷')
                        ],
                        saved: const {},
                        busyFavorites: const {},
                        onFavorite: (_) {},
                        onOpen: (_) {},
                        onBack: () {}));
        await tester.pumpWidget(ProviderScope(
            overrides: [placeRepositoryProvider.overrideWithValue(null)],
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                home: RepaintBoundary(
                    key: const ValueKey('review'), child: body))));
        await tester.pumpAndSettle();
        if (screen == 'map') {
          await tester.tap(find.text('世界之窗'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(launch.calls, isEmpty);
        await expectLater(find.byKey(const ValueKey('review')),
            matchesGoldenFile('goldens/explore-$screen-${width.toInt()}.png'));
        if (screen == 'ticket') {
          await tester.ensureVisible(find.text('前往购买'));
          await tester.tap(find.text('前往购买'));
          await tester.pumpAndSettle();
          expect(launch.calls, ['https://official.example/tickets/day']);
          expect(find.text('已支付'), findsNothing);
          expect(find.text('全日票'), findsOneWidget);
        }
      });
    }
  }
}
