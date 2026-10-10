import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/application/nearby_story_points.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/presentation/companion_point_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
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
  });

  for (final size in [const Size(390, 844), const Size(360, 800)]) {
    testWidgets('point directory matches ${size.width.toInt()}px design',
        (tester) async {
      await _open(tester, size: size);
      expect(find.text('选一处，\n慢慢靠近。', findRichText: true), findsOneWidget);
      expect(find.text('自动发现的下一处'), findsOneWidget);
      expect(find.byKey(const ValueKey('companion-point-p1')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('point-picker-capture')),
        matchesGoldenFile('goldens/point-picker-${size.width.toInt()}.png'),
      );
      const evidence = String.fromEnvironment('POINT_PICKER_EVIDENCE_DIR');
      if (evidence.isNotEmpty) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('point-picker-capture')));
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
              '$evidence/companion-point-picker-${size.width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets('manual selection returns only the chosen point', (tester) async {
    final results = <CompanionPointChoice?>[];
    await _open(tester, results: results);
    await tester.tap(find.byKey(const ValueKey('companion-point-p3')));
    await tester.pumpAndSettle();
    expect(results.single?.fragmentId, 'p3');
    expect(find.byType(CompanionPointPicker), findsNothing);
  });

  testWidgets('automatic selection differs from dismissing without a change',
      (tester) async {
    final results = <CompanionPointChoice?>[];
    await _open(tester, results: results, automatic: false);
    await tester.tap(find.byKey(const ValueKey('companion-point-auto')));
    await tester.pumpAndSettle();
    expect(results.single, isA<CompanionPointChoice>());
    expect(results.single!.fragmentId, isNull);
    await tester.tap(find.text('换一处'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('companion-point-close')));
    await tester.pumpAndSettle();
    expect(results.last, isNull);
  });

  testWidgets('search and filters use public places and exploration status',
      (tester) async {
    final points = [
      _point(1),
      _point(2, heard: true),
      _point(3, triggered: true)
    ];
    await _open(tester, points: points);
    await tester
        .tap(find.byKey(const ValueKey('companion-point-filter-unexplored')));
    await tester.pump();
    expect(find.byKey(const ValueKey('companion-point-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('companion-point-p2')), findsNothing);
    expect(find.byKey(const ValueKey('companion-point-p3')), findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('companion-point-filter-heard')));
    await tester.pump();
    expect(find.byKey(const ValueKey('companion-point-p2')), findsOneWidget);
    expect(find.byKey(const ValueKey('companion-point-p1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('companion-point-filter-all')));
    await tester.enterText(
        find.byKey(const ValueKey('companion-point-search')), '会馆');
    await tester.pump();
    expect(find.byKey(const ValueKey('companion-point-p3')), findsOneWidget);
    expect(find.byKey(const ValueKey('companion-point-p2')), findsNothing);
    expect(find.text('未公开的故事标题'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('companion-point-search')), '不存在');
    await tester.pump();
    expect(find.text('没有找到这个地点，换个名字试试。'), findsOneWidget);
  });

  testWidgets('live distance changes never move rows under a finger',
      (tester) async {
    final updates = ValueNotifier<List<NearbyStoryPoint>>([
      _point(1, distance: 100),
      _point(2, distance: 200),
      _point(3, distance: 300),
    ]);
    addTearDown(updates.dispose);
    await _open(tester, updates: updates);
    final firstY =
        tester.getTopLeft(find.byKey(const ValueKey('companion-point-p1'))).dy;
    updates.value = [
      _point(3, distance: 10),
      _point(2, distance: 20),
      _point(1, distance: 30),
      _point(4, distance: 1),
    ];
    await tester.pump();
    final row1 = find.byKey(const ValueKey('companion-point-p1'));
    final row2 = find.byKey(const ValueKey('companion-point-p2'));
    final row3 = find.byKey(const ValueKey('companion-point-p3'));
    expect(tester.getTopLeft(row1).dy, firstY);
    expect(tester.getTopLeft(row1).dy, lessThan(tester.getTopLeft(row2).dy));
    expect(tester.getTopLeft(row2).dy, lessThan(tester.getTopLeft(row3).dy));
    expect(
        find.descendant(of: row1, matching: find.text('30')), findsOneWidget);
    updates.value = [_point(3, distance: 2), _point(1, distance: 1)];
    await tester.pump();
    expect(find.byKey(const ValueKey('companion-point-p2')), findsNothing);
    expect(tester.getTopLeft(row1).dy, lessThan(tester.getTopLeft(row3).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hundreds of places stay lazy and searchable', (tester) async {
    final points = List.generate(
        500,
        (index) =>
            _point(index + 1, name: '地点 ${index + 1}', distance: index * 20));
    await _open(tester, points: points);
    expect(find.byKey(const ValueKey('companion-point-p500')), findsNothing);
    expect(find.byType(InkWell).evaluate().length, lessThan(25));
    await tester.enterText(
        find.byKey(const ValueKey('companion-point-search')), '地点 500');
    await tester.pump();
    expect(find.byKey(const ValueKey('companion-point-p500')), findsOneWidget);
    expect(find.text('10.0'), findsOneWidget);
    expect(find.text('公里'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no location orders by route and shows unknown distances',
      (tester) async {
    await _open(tester,
        points: [_point(3), _point(1), _point(2)], hasLocation: false);
    final row1 = find.byKey(const ValueKey('companion-point-p1'));
    final row2 = find.byKey(const ValueKey('companion-point-p2'));
    expect(tester.getTopLeft(row1).dy, lessThan(tester.getTopLeft(row2).dy));
    expect(find.text('距离待定'), findsNWidgets(3));
    expect(find.text('等待定位'), findsOneWidget);
  });

  testWidgets('keyboard and large text keep search and results reachable',
      (tester) async {
    await _open(tester,
        size: const Size(360, 800), textScale: 2, keyboardHeight: 300);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('companion-point-search')).hitTestable(),
        findsOneWidget);
    expect(find.byKey(const ValueKey('companion-point-close')).hitTestable(),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('companion-point-search')), '南城门');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('companion-point-p1')),
      150,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('companion-point-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  List<NearbyStoryPoint>? points,
  List<CompanionPointChoice?>? results,
  ValueNotifier<List<NearbyStoryPoint>>? updates,
  bool automatic = true,
  bool hasLocation = true,
  double textScale = 1,
  double keyboardHeight = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        viewInsets: EdgeInsets.only(bottom: keyboardHeight),
      ),
      child: RepaintBoundary(
        key: const ValueKey('point-picker-capture'),
        child: child!,
      ),
    ),
    home: Builder(builder: (context) {
      Widget picker(List<NearbyStoryPoint> values) => CompanionPointPicker(
            routeTitle: '南头古城',
            points: values,
            targetId: 'p1',
            automatic: automatic,
            hasLocation: hasLocation,
          );
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Center(
          child: TextButton(
            onPressed: () async {
              final result = await showModalBottomSheet<CompanionPointChoice>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: false,
                backgroundColor: AppColors.paper,
                barrierColor: const Color(0x60252824),
                shape: const Border(top: BorderSide(color: Color(0x77252824))),
                constraints: BoxConstraints(
                    maxHeight: size.height - (size.width <= 375 ? 44 : 57)),
                builder: (_) => updates == null
                    ? picker(points ?? _points)
                    : ValueListenableBuilder<List<NearbyStoryPoint>>(
                        valueListenable: updates,
                        builder: (_, values, __) => picker(values),
                      ),
              );
              results?.add(result);
            },
            child: const Text('换一处'),
          ),
        ),
      );
    }),
  ));
  await tester.tap(find.text('换一处'));
  await tester.pumpAndSettle();
}

final _names = [
  '南城门',
  '中山南街',
  '东莞会馆',
  '关帝庙',
  '新安县衙',
  '报德广场',
  '南头古城博物馆',
  '绅缙街',
  '北城门',
  '九街',
  '古城墙遗址',
  '聚秀街',
];
final _captions = [
  '一座城的入口',
  '街巷之间的日常',
  '异乡人的相聚之地',
  '檐下的旧时光',
  '从这里，读一座城',
  '在树影下停一停',
  '时间留下的证词',
  '拐角之后，别有生活',
  '城的另一面',
  '在巷子里听见今天',
  '沿着城的边缘走',
  '把步子放慢一些',
];
final _distances = [
  120,
  45,
  260,
  270,
  390,
  510,
  620,
  730,
  860,
  960,
  1120,
  1260
];
final _points = List.generate(
    12,
    (index) => _point(index + 1,
        distance: _distances[index].toDouble(),
        heard: [1, 3, 5, 9].contains(index)));

NearbyStoryPoint _point(int position,
        {String? name,
        double? distance,
        bool heard = false,
        bool triggered = false}) =>
    NearbyStoryPoint(
      fragment: StoryFragment(
        id: 'p$position',
        position: position,
        placeName: name ?? _names[(position - 1) % 12],
        safePreview: _captions[(position - 1) % 12],
        title: triggered || heard ? '未公开的故事标题' : null,
        state: heard
            ? 'collected'
            : triggered
                ? 'revealed'
                : 'undiscovered',
        interactionType: 'observe',
        reviewState: 'approved',
        triggerRegion: const TriggerRegion(
          latitude: 22.542,
          longitude: 113.925,
          entryRadiusM: 40,
          exitRadiusM: 65,
          maxAccuracyM: 40,
          qualifyingSamples: 2,
          sampleWindowSeconds: 10,
          cooldownSeconds: 120,
          auditState: 'approved',
        ),
        audio: const NarrationAsset(
            url: '/never-played.mp3',
            mimeType: 'audio/mpeg',
            sizeBytes: 100,
            scriptVersion: 'v1'),
      ),
      status: heard
          ? NearbyStoryPointStatus.heard
          : triggered
              ? NearbyStoryPointStatus.triggered
              : NearbyStoryPointStatus.outside,
      distanceMeters: distance ?? position * 100,
    );
