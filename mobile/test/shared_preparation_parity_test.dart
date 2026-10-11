import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/data/travel_plan_store.dart';
import 'package:jiandi/features/experience/domain/community_models.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/domain/discovery_location.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/offline_package_controller.dart';
import 'package:jiandi/features/experience/presentation/community/note_compose_page.dart';
import 'package:jiandi/features/experience/presentation/community/note_detail_page.dart';
import 'package:jiandi/features/experience/presentation/community/notes_controller.dart';
import 'package:jiandi/features/experience/presentation/travel/guide_preparation.dart';
import 'package:jiandi/features/experience/presentation/travel/preparation_page.dart';
import 'package:jiandi/features/experience/presentation/travel/travel_pages.dart';
import 'package:jiandi/features/experience/presentation/travel/travel_providers.dart';
import 'travel_preparation_test.dart' as fixture;

const exampleItems = [
  GuidePreparationItem('带好购票证件', body: '把购票使用的证件和入园凭证放在一起。'),
  GuidePreparationItem('帽子、防晒与雨具', body: '海边日晒强，排室外项目时很用得上。'),
  GuidePreparationItem('充电宝与舒适的鞋', body: '查演出时间、拍照都耗电，园区也比想象中大。'),
];
const examplePlace = CommunityPlace(
    fragmentId: 'ocean-entry',
    name: '入口',
    routeSlug: 'ocean',
    routeTitle: '长隆海洋王国',
    citySlug: 'zhuhai',
    cityName: '珠海');
CommunityPost examplePost({bool second = false}) => CommunityPost(
      id: second ? 'second' : 'guide',
      fragmentId: 'ocean-entry',
      category: CommunityCategory.guide,
      author:
          CommunityAuthor(displayName: second ? '小满' : '阿岚', avatar: 'default'),
      media: const [],
      likeCount: 0,
      commentCount: 12,
      viewerHasLiked: false,
      viewerIsAuthor: false,
      createdAt: DateTime(2026, 10, 9, 18, 42),
      place: examplePlace,
      title: second ? '带孩子去，别把行程排太满' : '第一次去海洋王国，这三样先准备好',
      body: '从早上入园待到傍晚，我最庆幸带了遮阳帽。背包不用塞太满，先把这几样收好，其他的到了再看。',
      preparationItems: exampleItems,
    );

class _Repo extends DemoExperienceRepository {
  @override
  Future<List<CommunityPlace>> communityPlaces() async => [examplePlace];
  @override
  Future<CommunityPost> communityPost(String id) async => examplePost();
  @override
  Future<CommunityPage<CommunityComment>> communityComments(String id,
          {String? cursor, int limit = 20}) async =>
      CommunityPage(items: [
        CommunityComment(
            id: 'c1',
            postId: id,
            body: '帽子真的需要，下午排队会晒。',
            author: const CommunityAuthor(displayName: '小禾', avatar: 'default'),
            viewerIsAuthor: false,
            createdAt: DateTime(2026, 10, 10, 9, 16)),
      ]);
}

class _Location extends NotesLocation {
  @override
  Future<DiscoveryLocationSample?> build() async => null;
}

class _Draft implements TourStore {
  Map<String, dynamic> data = {
    'title': '第一次去海洋王国，这三样先准备好',
    'body': '从早上入园待到傍晚，我最庆幸带了遮阳帽。整理了一个小清单，第一次去的话可以直接带走。',
    'category': 'guide',
    'fragment': 'ocean-entry',
    'preparation_items': exampleItems.map((i) => i.toJson()).toList()
  };
  @override
  Future<Map<String, dynamic>?> readJson(String key) async => data;
  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {
    data = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final font in {
      'Noto Serif SC': 'NotoSerifSC.ttf',
      'Noto Sans SC': 'NotoSansSC.ttf',
      'Georgia': 'Gelasio.ttf',
      'Inter': 'Inter.ttf'
    }.entries) {
      await (FontLoader(font.key)
            ..addFont(rootBundle.load('assets/fonts/${font.value}')))
          .load();
    }
  });
  testWidgets(
      'guide import keeps the page and local checklist supports inline add and checking',
      (tester) async {
    Future<void> settleIo() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
      }
      await tester.pumpAndSettle();
    }

    sqfliteFfiInit();
    late Directory dir;
    late TravelPlanStore store;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('preparation-parity-');
      store = await TravelPlanStore.open(dir, 'api|one',
          factory: databaseFactoryFfi);
    });
    addTearDown(() async {
      await store.close();
      await dir.delete(recursive: true);
    });
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) =>
              Scaffold(body: GuideChecklist(examplePost(), showItems: false))),
      GoRoute(
          path: '/travel/ocean',
          builder: (_, __) => const TravelPlanPage(id: 'ocean')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue('one'),
      experienceRepositoryProvider.overrideWithValue(_Repo()),
      travelStoreProvider.overrideWith((ref) async => store),
      offlineAwareRouteProvider('ocean')
          .overrideWith((ref) async => fixture.sample()),
    ], child: MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleIo();
    await tester.runAsync(() async {
      await tester.tap(find.text('加入我的准备'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await settleIo();
    expect(find.byType(TravelPlanPage), findsNothing);
    expect(find.text('已加入 · 查看'), findsOneWidget);
    expect((await tester.runAsync(() => store.tasks('ocean')))!.length, 3);
    await tester.runAsync(() async {
      await tester.tap(find.text('已加入 · 查看'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await settleIo();
    final rows = (await tester.runAsync(() => store.tasks('ocean')))!;
    final first = find.byKey(ValueKey('preparation-task-${rows.first['id']}'));
    await tester.ensureVisible(first);
    await tester.runAsync(() async {
      await tester.tap(first);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleIo();
    expect(
        (await tester.runAsync(() => store.tasks('ocean')))!.first['done'], 1);
    final input = find.byKey(const ValueKey('preparation-custom-input'));
    await tester.ensureVisible(input);
    await tester.enterText(input, '水壶');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('preparation-custom-add')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settleIo();
    expect((await tester.runAsync(() => store.tasks('ocean')))!.last['title'],
        '水壶');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320, 390]) {
    for (final screen in ['place', 'note', 'mine', 'write', 'empty']) {
      testWidgets('shared preparation design $screen $width full page',
          (tester) async {
        tester.view.physicalSize = Size(width.toDouble(), 810);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final initial = switch (screen) {
          'place' => '/',
          'note' => '/community/post/guide',
          'write' => '/community/write',
          _ => '/travel/ocean'
        };
        final router = GoRouter(initialLocation: initial, routes: [
          GoRoute(
              path: '/',
              builder: (_, __) => const PreparationPage(slug: 'ocean')),
          GoRoute(
              path: '/route/ocean/prepare',
              builder: (_, __) => const PreparationPage(slug: 'ocean')),
          GoRoute(
              path: '/travel/ocean',
              builder: (_, __) => const TravelPlanPage(id: 'ocean')),
          GoRoute(
              path: '/community/write',
              builder: (_, __) => const NoteComposePage(
                  fragmentId: 'ocean-entry',
                  initialCategory: CommunityCategory.guide)),
          GoRoute(
              path: '/community/post/:id',
              builder: (_, state) =>
                  NoteDetailPage(postId: state.pathParameters['id']!)),
        ]);
        addTearDown(router.dispose);
        final rows = [
          for (final (i, item) in exampleItems.indexed)
            <String, Object?>{
              'id': '$i',
              'post_id': 'guide',
              'title': item.title,
              'body': item.body,
              'done': i == 0 ? 1 : 0
            },
          <String, Object?>{
            'id': 'self',
            'post_id': null,
            'title': '带一件薄外套',
            'body': '',
            'done': 0
          }
        ];
        await tester.pumpWidget(ProviderScope(
            overrides: [
              currentUserIdProvider.overrideWithValue('one'),
              experienceRepositoryProvider.overrideWithValue(_Repo()),
              tourStoreProvider.overrideWithValue(_Draft()),
              notesLocationProvider.overrideWith(_Location.new),
              offlineAwareRouteProvider('ocean')
                  .overrideWith((ref) async => fixture.sample()),
              routeGuidesProvider('ocean').overrideWith(
                  (ref) async => [examplePost(), examplePost(second: true)]),
              travelPlanProvider('ocean')
                  .overrideWith((ref) async => TravelPlan.fromMap({
                        'id': 'ocean',
                        'slug': 'ocean',
                        'title': '长隆海洋王国',
                        'city': '珠海',
                        'image': '',
                        'visit_date': '2026-10-17'
                      })),
              preparationTasksProvider('ocean')
                  .overrideWith((ref) async => screen == 'empty' ? [] : rows),
              importedGuidesProvider('ocean')
                  .overrideWith((ref) async => screen == 'mine'
                      ? [
                          {
                            'post_id': 'guide',
                            'author': '阿岚',
                            'title': examplePost().title
                          }
                        ]
                      : []),
            ],
            child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                routerConfig: router)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Capture the complete laid-out document, not an isolated checklist.
        await expectLater(
            find.byKey(const ValueKey('preparation-document')).last,
            matchesGoldenFile('goldens/shared-preparation-$screen-$width.png'));
        if (screen == 'mine') {
          expect(tester.getTopLeft(find.text('来自阿岚的攻略')).dy,
              lessThan(tester.getTopLeft(find.text('带好购票证件')).dy));
          expect(find.text('1 / 4 已备好'), findsOneWidget);
          expect(find.text('自行添加的票据不代表平台已核验订单。'), findsNothing);
          await tester.ensureVisible(find.text('查看原文 ↗'));
          await tester.tap(find.text('查看原文 ↗'));
          await tester.pumpAndSettle();
          expect(find.byType(NoteDetailPage), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
          expect(
              router.routeInformationProvider.value.uri.path, '/travel/ocean');
        }
        if (screen == 'place') {
          expect(find.text('游玩准备'), findsOneWidget);
          expect(find.byType(Image), findsNothing);
          await tester.tap(find.text('开放与入园须知'));
          await tester.pumpAndSettle();
          expect(find.text('接驳班车'), findsOneWidget);
          expect(find.text('信息来源'), findsOneWidget);
        }
        if (screen == 'note') {
          await tester.ensureVisible(find.text('评论'));
          await tester.tap(find.text('评论'));
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
          expect(find.text('发送'), findsOneWidget);
        }
        if (screen == 'write') {
          expect(find.text('01'), findsNothing);
          expect(find.text('谁可以看'), findsNothing);
          expect(find.text('分享见闻'), findsOneWidget);
        }
        if (screen == 'empty') expect(find.text('还没有准备清单'), findsOneWidget);
      });
    }
  }
}
