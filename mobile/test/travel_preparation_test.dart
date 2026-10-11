import 'dart:io';
import 'package:jiandi/features/experience/presentation/travel/guide_preparation.dart';
import 'package:jiandi/features/experience/domain/community_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/domain/models.dart';
import 'package:jiandi/features/experience/domain/travel_preparation.dart';
import 'package:jiandi/features/experience/data/travel_plan_store.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/travel/preparation_page.dart';
import 'package:jiandi/features/experience/presentation/travel/travel_providers.dart';
import 'package:jiandi/features/experience/presentation/travel/travel_pages.dart';
import 'package:jiandi/features/experience/presentation/offline_package_controller.dart';

RouteExperience sample({bool configured = true}) => RouteExperience(
    id: 'ocean',
    slug: 'ocean',
    title: '长隆海洋王国',
    subtitle: '海洋展馆、游乐设施与剧场演出',
    description: '海洋王国',
    durationMinutes: 90,
    distanceKm: 1,
    difficulty: '轻松',
    theme: '主题乐园',
    heroImage: '',
    contentStatus: 'published',
    stops: const [],
    cityName: '珠海',
    district: '横琴',
    travelPreparation: TravelPreparation(configured
        ? {
            'enabled': true,
            'admission': 'ticket',
            'channel_name': '景区官方购票',
            'purchase_url': 'https://official.example/tickets',
            'source_url': 'https://official.example',
            'verified_on': '2026-10-11',
            'opening_hours': '以当日官方公告为准。',
            'transport': '横琴 · 富祥湾',
            'notices': '请携带购票时使用的有效证件。',
            'extra_items': [
              {'title': '接驳班车', 'body': '以官方当日班次为准。', 'url': ''}
            ],
          }
        : {}));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final entry in {
      'Noto Serif SC': 'NotoSerifSC.ttf',
      'Noto Sans SC': 'NotoSansSC.ttf',
      'Inter': 'Inter.ttf',
      'Georgia': 'Gelasio.ttf'
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load('assets/fonts/${entry.value}'));
      await loader.load();
    }
  });
  test('official URL validation and optional preparation fields', () {
    for (final value in [
      'http://a.example',
      'javascript:alert(1)',
      'file:///tmp/a',
      'https://a:b@host.example',
      'https://127.0.0.1',
      'https://a.local',
      'https://a.example:5000'
    ]) {
      expect(safePreparationUri(value), isNull);
    }
    expect(
        safePreparationUri('https://official.example/ticket?date=2026-10-17'),
        isNotNull);
    expect(sample().travelPreparation.items.length, 4);
    expect(sample(configured: false).travelPreparation.enabled, isFalse);
    expect(sample().travelPreparation.canBook, isTrue);
    expect(
        const TravelPreparation({'enabled': true, 'admission': 'ticket'})
            .canBook,
        isFalse);
  });
  test('wallet persists, isolates accounts, preserves dates and deletes files',
      () async {
    final dir = await Directory.systemTemp.createTemp('travel-test-');
    final first =
        await TravelPlanStore.open(dir, 'api|one', factory: databaseFactoryFfi);
    final other =
        await TravelPlanStore.open(dir, 'api|two', factory: databaseFactoryFfi);
    try {
      await first.add(sample());
      await first.setDate('ocean', DateTime(2026, 10, 17));
      await first.add(sample());
      expect((await first.plan('ocean'))!.date, '2026-10-17');
      expect(await other.plans(), isEmpty);
      final file = File('${dir.path}/ticket.pdf');
      await file.writeAsString('%PDF-1.4\nlocal ticket');
      await first.importReceipt('ocean', '我的门票.pdf', file);
      final receipt = (await first.receipts('ocean')).single;
      expect(receipt.kind, 'pdf');
      expect(await first.file(receipt).exists(), isTrue);
      expect(await other.receipts('ocean'), isEmpty);
      // Recreate the original v1 schema with real saved tickets before upgrading.
      await first.database.execute('DROP TABLE preparation_tasks');
      await first.database.execute('DROP TABLE guide_imports');
      await first.database.setVersion(1);
      await first.close();
      final reopened = await TravelPlanStore.open(dir, 'api|one',
          factory: databaseFactoryFfi);
      expect((await reopened.receipts('ocean')).length, 1);
      expect(await reopened.tasks('ocean'), isEmpty);
      expect((await reopened.plan('ocean'))!.date, '2026-10-17');
      await reopened.removePlan('ocean');
      expect(await reopened.plans(), isEmpty);
      expect(await reopened.file(receipt).exists(), isFalse);
      await reopened.close();
    } finally {
      await other.close();
      await dir.delete(recursive: true);
    }
  });
  test(
      'guide imports deduplicate, preserve progress, isolate accounts and survive reopening',
      () async {
    final dir = await Directory.systemTemp.createTemp('guide-test-');
    var store =
        await TravelPlanStore.open(dir, 'api|one', factory: databaseFactoryFfi);
    final other =
        await TravelPlanStore.open(dir, 'api|two', factory: databaseFactoryFfi);
    final post = CommunityPost(
        id: 'guide-1',
        fragmentId: 'fragment',
        category: CommunityCategory.guide,
        author: const CommunityAuthor(displayName: '阿岚', avatar: 'default'),
        media: const [],
        likeCount: 0,
        commentCount: 0,
        viewerHasLiked: false,
        viewerIsAuthor: false,
        createdAt: null,
        title: '出发前准备',
        preparationItems: const [
          GuidePreparationItem('证件'),
          GuidePreparationItem('雨具')
        ],
        place: const CommunityPlace(
            fragmentId: 'fragment',
            name: '入口',
            routeSlug: 'ocean',
            routeTitle: '海洋王国',
            citySlug: 'zhuhai',
            cityName: '珠海'));
    try {
      await store.importGuide(sample(), post);
      await store.checkTask(
          (await store.tasks('ocean')).first['id'] as String, true);
      await store.importGuide(sample(), post);
      expect((await store.tasks('ocean')).length, 2);
      expect((await store.tasks('ocean')).first['done'], 1);
      expect((await store.guides('ocean')).single['author'], '阿岚');
      expect(await other.tasks('ocean'), isEmpty);
      await store.addTask('ocean', '水壶');
      await store.close();
      store = await TravelPlanStore.open(dir, 'api|one',
          factory: databaseFactoryFfi);
      expect((await store.tasks('ocean')).length, 3);
      expect((await store.tasks('ocean')).first['done'], 1);
      await store.removePlan('ocean');
      expect(await store.tasks('ocean'), isEmpty);
      expect(await store.guides('ocean'), isEmpty);
    } finally {
      await store.close();
      await other.close();
      await dir.delete(recursive: true);
    }
  });

  test('receipt importer rejects executable and oversized files', () async {
    expect(receiptKind(Uint8List.fromList('MZfake.pdf'.codeUnits)), isNull);
    final dir = await Directory.systemTemp.createTemp('travel-limits-');
    final store =
        await TravelPlanStore.open(dir, 'api|one', factory: databaseFactoryFfi);
    try {
      await store.add(sample());
      final file = File('${dir.path}/fake.pdf');
      await file.writeAsString('not a PDF');
      await expectLater(store.importReceipt('ocean', 'fake.pdf', file),
          throwsFormatException);
      final large = await file.open(mode: FileMode.write);
      await large.truncate(TravelPlanStore.maxReceiptBytes + 1);
      await large.close();
      await expectLater(store.importReceipt('ocean', 'huge.pdf', file),
          throwsFormatException);
      expect(await store.receipts('ocean'), isEmpty);
    } finally {
      await store.close();
      await dir.delete(recursive: true);
    }
  });
  for (final width in [320, 390]) {
    testWidgets('official preparation $width has no prices and no overflow',
        (tester) async {
      tester.view.physicalSize = Size(width.toDouble(), 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('one'),
            travelPlanProvider('ocean').overrideWith((ref) async => null)
          ],
          child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(23),
                      child: RepaintBoundary(
                          key: const ValueKey('preparation'),
                          child: ColoredBox(
                              color: AppColors.paper,
                              child: PreparationBody(route: sample()))))))));
      await tester.pumpAndSettle();
      expect(find.text('前往官方购票'), findsOneWidget);
      expect(find.textContaining('¥'), findsNothing);
      expect(find.text('接驳班车'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('preparation')),
          matchesGoldenFile('goldens/travel-preparation-$width.png'));
      await tester.tap(find.text('入园须知'));
      await tester.pumpAndSettle();
      expect(find.text('请携带购票时使用的有效证件。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'imported preparation shows source, progress and a paper checklist',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          preparationTasksProvider('ocean').overrideWith((ref) async => [
                {
                  'id': '1',
                  'post_id': 'guide',
                  'title': '带好购票证件',
                  'body': '把证件和入园凭证放在一起。',
                  'done': 1
                },
                {
                  'id': '2',
                  'post_id': 'guide',
                  'title': '帽子、防晒与雨具',
                  'body': '',
                  'done': 0
                },
                {
                  'id': '3',
                  'post_id': 'guide',
                  'title': '充电宝与舒适的鞋',
                  'body': '',
                  'done': 0
                },
              ]),
          importedGuidesProvider('ocean').overrideWith((ref) async => [
                {'post_id': 'guide', 'author': '阿岚', 'title': '第一次去海洋王国'}
              ]),
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            home: const RepaintBoundary(
                key: ValueKey('guide-wallet'),
                child: Scaffold(
                    backgroundColor: AppColors.paper,
                    body: Padding(
                        padding: EdgeInsets.all(23),
                        child: MyPreparation('ocean')))))));
    await tester.pumpAndSettle();
    expect(find.text('已备好 1 / 3'), findsOneWidget);
    expect(find.text('查看原文'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('guide-wallet')),
        matchesGoldenFile('goldens/guide-wallet-390.png'));
  });

  testWidgets('wallet displays manually added receipts, never issued status',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          travelPlanProvider('ocean')
              .overrideWith((ref) async => TravelPlan.fromMap({
                    'id': 'ocean',
                    'slug': 'ocean',
                    'title': '长隆海洋王国',
                    'city': '珠海',
                    'image': '',
                    'visit_date': '2026-10-17'
                  })),
          travelReceiptsProvider('ocean').overrideWith((ref) async => [
                TravelReceipt.fromMap({
                  'id': 'receipt',
                  'route_id': 'ocean',
                  'name': '海洋王国门票.pdf',
                  'file_name': 'receipt.pdf',
                  'kind': 'pdf'
                })
              ]),
          offlineAwareRouteProvider('ocean')
              .overrideWith((ref) async => sample())
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            home: const RepaintBoundary(
                key: ValueKey('wallet'), child: TravelPlanPage(id: 'ocean')))));
    await tester.pumpAndSettle();
    expect(find.text('本人添加'), findsOneWidget);
    expect(find.text('已出票'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('wallet')),
        matchesGoldenFile('goldens/travel-wallet-390.png'));
  });
}
