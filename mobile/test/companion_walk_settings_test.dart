import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/companion_walk_settings.dart';
import 'package:jiandi/features/experience/presentation/location_mode_controller.dart';
import 'package:jiandi/features/experience/presentation/offline_package_controller.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(360, 800)]) {
    testWidgets('preparation sheet fits ${size.width.toInt()}px phone',
        (tester) async {
      await _open(tester, size: size);
      expect(find.text('准备好，\n再出发。', findRichText: true), findsOneWidget);
      expect(find.text('真实行走'), findsOneWidget);
      expect(find.text('模拟预览'), findsOneWidget);
      expect(find.byKey(const ValueKey('companion-settings-done')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selection persists and ordinary completion never starts a walk',
      (tester) async {
    final store = _ModeStore();
    final results = <bool>[];
    await _open(tester, store: store, results: results);
    await tester
        .tap(find.byKey(const ValueKey('companion-settings-mode-simulated')));
    await tester.pumpAndSettle();
    expect(store.mode, TourLocationMode.simulated);
    await _finish(tester);
    expect(results, [false]);
    expect(find.byKey(const ValueKey('companion-walk-settings-sheet')),
        findsNothing);
  });

  testWidgets('start requires explicit preparation confirmation',
      (tester) async {
    final results = <bool>[];
    await _open(tester, results: results, start: true);
    expect(results, isEmpty);
    await tester.tap(find.byTooltip('关闭行走设置'));
    await tester.pumpAndSettle();
    expect(results, [false]);

    await tester.tap(find.text('打开准备'));
    await tester.pumpAndSettle();
    await _finish(tester);
    expect(results, [false, true]);
  });

  testWidgets('failed preference write restores saved mode and blocks start',
      (tester) async {
    final store = _ModeStore()..failWrites = true;
    await _open(tester, store: store, start: true);
    await tester
        .tap(find.byKey(const ValueKey('companion-settings-mode-simulated')));
    await tester.pumpAndSettle();
    expect(store.mode, TourLocationMode.real);
    expect(find.text('定位方式未保存，请重新选择后重试。'), findsOneWidget);
    expect(
        tester
            .widget<InkWell>(
                find.byKey(const ValueKey('companion-settings-done')))
            .onTap,
        isNull);

    store.failWrites = false;
    await tester
        .tap(find.byKey(const ValueKey('companion-settings-mode-simulated')));
    await tester.pumpAndSettle();
    expect(store.mode, TourLocationMode.simulated);
    expect(find.text('定位方式未保存，请重新选择后重试。'), findsNothing);
    expect(
        tester
            .widget<InkWell>(
                find.byKey(const ValueKey('companion-settings-done')))
            .onTap,
        isNotNull);
  });

  testWidgets('download reports progress and prevents duplicate requests',
      (tester) async {
    final offline = _OfflineController();
    await _open(tester, offline: offline, start: true);
    await tester.tap(find.byKey(const ValueKey('companion-settings-offline')));
    await tester.pump();
    expect(offline.downloads, 1);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<InkWell>(
                find.byKey(const ValueKey('companion-settings-offline')))
            .onTap,
        isNull);
    expect(
        tester
            .widget<InkWell>(
                find.byKey(const ValueKey('companion-settings-done')))
            .onTap,
        isNull);

    offline.finish(const OfflinePackageStatus(
      phase: OfflinePackagePhase.complete,
      complete: 3,
      total: 3,
      message: '版本 v1 · 完整性校验通过',
    ));
    await tester.pumpAndSettle();
    expect(find.text('已准备 ✓'), findsOneWidget);
    expect(find.text('版本 v1 · 完整性校验通过'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
        tester
            .widget<InkWell>(
                find.byKey(const ValueKey('companion-settings-offline')))
            .onTap,
        isNull);
    expect(
        tester
            .widget<InkWell>(
                find.byKey(const ValueKey('companion-settings-done')))
            .onTap,
        isNotNull);
  });

  testWidgets('failed and stale offline packages remain recoverable',
      (tester) async {
    final offline = _OfflineController(
      const OfflinePackageStatus(
        phase: OfflinePackagePhase.stale,
        message: '离线包有新版本，点击更新',
      ),
    );
    await _open(tester, offline: offline);
    expect(find.text('更新 ↓'), findsOneWidget);
    expect(find.text('离线包有新版本，点击更新'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('companion-settings-offline')));
    await tester.pump();
    offline.finish(const OfflinePackageStatus(
      phase: OfflinePackagePhase.failed,
      message: '网络中断，点击重试',
    ));
    await tester.pumpAndSettle();
    expect(find.text('网络中断，点击重试'), findsOneWidget);
    expect(find.text('重试下载 ↓'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('companion-settings-offline')));
    await tester.pump();
    expect(offline.downloads, 2);
    offline.finish(
        const OfflinePackageStatus(phase: OfflinePackagePhase.complete));
    await tester.pumpAndSettle();
  });
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  _ModeStore? store,
  _OfflineController? offline,
  List<bool>? results,
  bool start = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final packageController = offline ?? _OfflineController();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      locationModeStoreProvider.overrideWithValue(store ?? _ModeStore()),
      offlinePackageControllerProvider.overrideWith2((_) => packageController),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                final result = await showCompanionWalkSettings(context,
                    route: _route, startAfterPreparation: start);
                results?.add(result);
              },
              child: const Text('打开准备'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('打开准备'));
  await tester.pumpAndSettle();
}

Future<void> _finish(WidgetTester tester) async {
  final done = find.byKey(const ValueKey('companion-settings-done'));
  await tester.ensureVisible(done);
  await tester.tap(done);
  await tester.pumpAndSettle();
}

class _ModeStore implements LocationModeStore {
  TourLocationMode mode = TourLocationMode.real;
  bool failWrites = false;

  @override
  Future<TourLocationMode> read() async => mode;

  @override
  Future<void> write(TourLocationMode value) async {
    if (failWrites) throw StateError('storage unavailable');
    mode = value;
  }
}

class _OfflineController extends OfflinePackageController {
  _OfflineController([this.initial = const OfflinePackageStatus.idle()])
      : super(const OfflinePackageKey('test-route', 'v1'));

  final OfflinePackageStatus initial;
  int downloads = 0;
  Completer<void>? _download;

  @override
  Future<OfflinePackageStatus> build() async => initial;

  @override
  Future<void> download(RouteExperience route) async {
    downloads++;
    _download = Completer<void>();
    state = const AsyncData(OfflinePackageStatus(
      phase: OfflinePackagePhase.downloading,
      complete: 1,
      total: 3,
    ));
    await _download!.future;
  }

  void finish(OfflinePackageStatus status) {
    state = AsyncData(status);
    _download?.complete();
    _download = null;
  }
}

const _route = RouteExperience(
  id: 'test-route',
  slug: 'test-route',
  title: '武康路 · 安福路',
  subtitle: '街道与故事',
  description: '沿着街道，慢慢走。',
  durationMinutes: 80,
  distanceKm: 2.4,
  difficulty: '轻松',
  theme: '城市漫游',
  heroImage: '',
  contentStatus: 'published',
  stops: [],
  audioTour: AudioTourManifest(
    title: '沿途的声音',
    centralQuestion: '',
    scriptVersion: 'v1',
    reviewState: 'approved',
    fieldAuditState: 'approved',
    productionReady: true,
    demoLabel: null,
    contentMethod: 'editorial',
    downloadSizeBytes: 1024,
    fragments: [],
  ),
);
