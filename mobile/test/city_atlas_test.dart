import 'package:jiandi/features/experience/presentation/places_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/presentation/city_atlas.dart';

RouteExperience place(String id,
        {String theme = '海边',
        String? category,
        double? lat = 22.5987158,
        double? lon = 114.3038915,
        String status = 'published'}) =>
    RouteExperience(
      id: id,
      slug: id,
      title: id,
      subtitle: '从街巷走向海边。',
      description: '城市故事。',
      durationMinutes: 75,
      distanceKm: 1.8,
      difficulty: '轻松',
      theme: theme,
      mapCategory: category,
      heroImage: '',
      contentStatus: status,
      stops: const [],
      centerLatitude: lat,
      centerLongitude: lon,
    );
void main() {
  test('atlas categories describe places, never delivery mechanics', () {
    expect(
        cityAtlasCategory(place('海边街区', theme: '海边', category: 'architecture')),
        '建筑');
    expect(cityAtlasCategory(place('南头古城', theme: '定位音频 · 碎片叙事')), '街巷');
    expect(cityAtlasCategory(place('上海城市生活', theme: '定位音频')), '其他');
    expect(cityAtlasCategory(place('人民公园', theme: '实地记录')), '公园');
    expect(cityAtlasCategory(place('永庆坊', theme: '西关与岭南文化')), '街巷');
    expect(cityAtlasCategory(place('海岛', theme: '海岛与文化建筑')), '海边');
  });

  test('only finite, geographic catalog coordinates are projected', () {
    expect(cityAtlasCoordinate(place('valid')),
        const Offset(114.3038915, 22.5987158));
    for (final route in [
      place('missing', lat: null, lon: null),
      place('zero', lat: 0, lon: 0),
      place('nan', lat: double.nan),
      place('outside', lon: 181)
    ]) {
      expect(cityAtlasCoordinate(route), isNull);
    }
  });

  for (final city in [
    'shenzhen',
    'shanghai',
    'guangzhou',
    'zhuhai',
    'shangqiu',
    'city-new'
  ]) {
    testWidgets('$city list, selection, pinch and pan share state',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [placeRepositoryProvider.overrideWithValue(null)],
          child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                  body: CityAtlas(
                      citySlug: city,
                      cityName: city,
                      routes: [
                        place('海边景点'),
                        place('街巷景点', theme: '老街', lat: 22.5381, lon: 113.9227),
                        place('未发布', status: 'draft')
                      ],
                      saved: const {},
                      busyFavorites: const {},
                      onFavorite: (_) {},
                      onOpen: (_) {},
                      onBack: () {})))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('place-row-海边景点')), findsOneWidget);
      expect(find.byKey(const ValueKey('city-map-canvas')), findsNothing);
      await tester.tap(find.text('街巷景点'));
      await tester.pumpAndSettle();
      final marker = find.byKey(const ValueKey('city-map-point-街巷景点'));
      final before = tester.getCenter(marker);
      final canvas = find.byKey(const ValueKey('city-map-canvas'));
      final center = tester.getCenter(canvas);
      final a = await tester.createGesture(pointer: 1),
          b = await tester.createGesture(pointer: 2);
      await a.down(center - const Offset(25, 0));
      await b.down(center + const Offset(25, 0));
      await a.moveTo(center - const Offset(70, 0));
      await b.moveTo(center + const Offset(70, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      await tester.dragFrom(center, const Offset(30, 20));
      await tester.pumpAndSettle();
      expect(tester.getCenter(marker), isNot(before));
      final relativeBefore =
          tester.getCenter(marker) - tester.getTopLeft(canvas);
      await tester.dragFrom(tester.getCenter(canvas), const Offset(0, 50));
      await tester.pumpAndSettle();
      final relativeAfter =
          tester.getCenter(marker) - tester.getTopLeft(canvas);
      expect(relativeAfter.dy, greaterThan(relativeBefore.dy + 20));

      expect(
          find.byKey(const ValueKey('city-map-place-sheet')), findsOneWidget);
      expect(find.text('随行'), findsNothing);
      await tester.tap(find.byTooltip('列表'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '海边景点');
      await tester.pumpAndSettle();
      expect(find.text('街巷景点'), findsNothing);
      await tester.tap(find.byTooltip('地图'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('city-map-point-街巷景点')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('long lists build lazily and paginate without losing filters',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [placeRepositoryProvider.overrideWithValue(null)],
        child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
                body: CityAtlas(
                    citySlug: 'shenzhen',
                    cityName: '深圳',
                    routes: List.generate(65, (i) => place('景点$i')),
                    saved: const {},
                    busyFavorites: const {},
                    onFavorite: (_) {},
                    onOpen: (_) {},
                    onBack: () {})))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('place-row-景点64')), findsNothing);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('place-row-景点64')), 600,
        scrollable: find.byType(Scrollable).first, maxScrolls: 30);
    expect(find.byKey(const ValueKey('place-row-景点64')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
