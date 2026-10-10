import 'package:flutter/material.dart';
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
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets(
        'map selection, filtering, zoom and return preserve context at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final routes = [
        place('海边景点'),
        place('街巷景点', theme: '老街', lat: 22.5381, lon: 113.9227),
        place('未发布', status: 'draft')
      ];
      final favorites = <String>[];
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Builder(
              builder: (context) => Scaffold(
                      body: CityAtlas(
                    citySlug: 'shenzhen',
                    cityName: '深圳',
                    routes: routes,
                    saved: const {},
                    busyFavorites: const {},
                    onFavorite: (route) => favorites.add(route.id),
                    onBack: () {},
                    onOpen: (route) => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                                appBar: AppBar(title: Text(route.title))))),
                  )))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('city-map-point-未发布')), findsNothing);
      final town = find.byKey(const ValueKey('city-map-point-街巷景点'));
      await tester.tap(town);
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('city-map-place-sheet'));
      expect(find.descendant(of: sheet, matching: find.text('街巷景点')),
          findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('放大地图')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('city-map-open')));
      await tester.pumpAndSettle();
      final location = tester.getCenter(town);
      await tester.tap(find.byKey(const ValueKey('city-map-open')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.getCenter(town), location);
      expect(find.descendant(of: sheet, matching: find.text('街巷景点')),
          findsOneWidget);
      await tester.tap(find.byTooltip('收藏街巷景点'));
      await tester.pumpAndSettle();
      expect(favorites, ['街巷景点']);
      await tester.tap(find.bySemanticsLabel(RegExp('查看全城')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('海边主题')));
      await tester.pumpAndSettle();
      expect(town, findsNothing);
      expect(find.descendant(of: sheet, matching: find.text('海边景点')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('missing coordinates remain readable without invented markers',
      (tester) async {
    String? opened;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: CityAtlas(
          citySlug: 'other',
          cityName: '其他城市',
          routes: [place('无坐标', lat: null, lon: null)],
          saved: const {},
          busyFavorites: const {},
          onFavorite: (_) {},
          onBack: () {},
          onOpen: (route) => opened = route.id,
        ))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('city-map-point-无坐标')), findsNothing);
    expect(find.text('以下景点暂无地图位置，仍可查看介绍'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('city-map-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('city-map-open')));
    expect(opened, '无坐标');
    expect(tester.takeException(), isNull);
  });
}
