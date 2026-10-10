import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/presentation/city_atlas.dart';
import 'package:jiandi/features/experience/presentation/city_atlas_geometry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cities = {
    'shenzhen': ('深圳', 9),
    'shanghai': ('上海', 16),
    'guangzhou': ('广州', 11),
    'zhuhai': ('珠海', 3),
    'shangqiu': ('商丘', 9),
  };
  setUpAll(() async {
    for (final entry in {
      'Noto Serif SC': 'NotoSerifSC.ttf',
      'Noto Sans SC': 'NotoSansSC.ttf',
      'Georgia': 'Gelasio.ttf',
      'Inter': 'Inter.ttf',
    }.entries) {
      await (FontLoader(entry.key)
            ..addFont(Future.value(ByteData.sublistView(
                await File('assets/fonts/${entry.value}').readAsBytes()))))
          .load();
    }
  });

  test('every content-package city has valid offline district boundaries',
      () async {
    final slugs = {'shenzhen', 'shanghai'};
    for (final file in Directory('../docs/content-packages')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      final data = jsonDecode(await file.readAsString());
      if (data is Map && data['city'] is Map) {
        slugs.add(data['city']['slug'] as String);
      }
    }
    for (final slug in slugs) {
      final districts = await loadCityAtlasDistricts(slug);
      expect(districts.length, cities[slug]!.$2, reason: slug);
      for (final district in districts) {
        expect(district.name, isNotEmpty);
        expect(district.polygons, isNotEmpty);
        for (final ring in district.polygons.expand((p) => p)) {
          expect(ring.length, greaterThanOrEqualTo(4));
          expect(ring.first, ring.last);
          expect(
              ring.every((p) =>
                  p.dx.isFinite &&
                  p.dy.isFinite &&
                  p.dx.abs() <= 180 &&
                  p.dy.abs() <= 85),
              isTrue);
        }
      }
    }
    expect(await loadCityAtlasDistricts('unknown-city'), isEmpty);
  });

  for (final city in cities.entries) {
    testWidgets('${city.key} renders district map', (tester) async {
      await tester.runAsync(() => loadCityAtlasDistricts(city.key));
      tester.view.physicalSize = const Size(390, 843);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
            body: RepaintBoundary(
          key: const ValueKey('atlas'),
          child: ColoredBox(
              color: AppColors.paper,
              child: CityAtlas(
                citySlug: city.key,
                cityName: city.value.$1,
                routes: const [],
                saved: const {},
                busyFavorites: const {},
                onFavorite: (_) {},
                onOpen: (_) {},
                onBack: () {},
              )),
        )),
      ));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('atlas')),
          matchesGoldenFile('goldens/atlas-${city.key}.png'));
    });
  }
}
