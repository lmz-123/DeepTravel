import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jiandi/core/theme/app_theme.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/community_models.dart';
import 'package:jiandi/features/experience/domain/discovery_location.dart';
import 'package:jiandi/features/experience/domain/tour_runtime.dart';
import 'package:jiandi/features/experience/presentation/active_tour_controller.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/community/notes_page.dart';
import 'package:jiandi/features/experience/presentation/community/notes_widgets.dart';
import 'package:jiandi/features/experience/presentation/community/notes_controller.dart';
import 'package:jiandi/features/experience/presentation/community/note_detail_page.dart';
import 'package:jiandi/features/experience/presentation/community/note_compose_page.dart';

const place = CommunityPlace(
    fragmentId: 'dameisha-0',
    name: '中央公共海滨广场',
    routeSlug: 'dameisha',
    routeTitle: '大梅沙',
    citySlug: 'shenzhen',
    cityName: '深圳',
    theme: '海边');
const shanghai = CommunityPlace(
    fragmentId: 'wukang-0',
    name: '武康大楼转角',
    routeSlug: 'wukang',
    routeTitle: '武康路',
    citySlug: 'shanghai',
    cityName: '上海',
    theme: '街巷');
CommunityPost fixturePost({bool detail = false, int photos = 1}) =>
    CommunityPost(
        id: 'sea',
        fragmentId: place.fragmentId,
        category: CommunityCategory.onSite,
        author: const CommunityAuthor(displayName: '阿岚', avatar: 'default'),
        media: [
          for (var index = 0; index < photos; index++)
            CommunityMedia(
                id: 'sea-photo-$index',
                url: '/community-media/sea-photo',
                mimeType: 'image/jpeg',
                width: 800,
                height: 800,
                position: index)
        ],
        likeCount: 26,
        commentCount: 2,
        viewerHasLiked: false,
        viewerIsAuthor: false,
        createdAt: DateTime(2026, 10, 4, 17, 42),
        place: place,
        title: '坐在海边，等天色慢下来。',
        body: detail
            ? '沿着海滨步道走到广场，找了个能看到海的位置坐下。\n没赶上日落也没关系。风吹过来的时候，才发现看海本来就不用做什么。\n我那天傍晚来，坐了大约四十分钟。离开前记得把身边的垃圾带走。'
            : '没赶上日落也没关系。坐了一会儿，才发现看海本来就不用做什么。');
CommunityComment comment(String id, String author, String body,
        {List<CommunityComment> replies = const []}) =>
    CommunityComment(
        id: id,
        postId: 'sea',
        body: body,
        author: CommunityAuthor(displayName: author, avatar: 'default'),
        viewerIsAuthor: false,
        createdAt: DateTime(2026, 10, 4, 18, 23),
        replyCount: replies.length,
        replyPreview: replies);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List photo;
  late Uint8List street;
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final (family, file) in [
      ('Noto Serif SC', 'NotoSerifSC.ttf'),
      ('Noto Sans SC', 'NotoSansSC.ttf'),
      ('Inter', 'Inter.ttf'),
      ('Georgia', 'Gelasio.ttf')
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
    photo = await File('test/fixtures/discovery/coast.jpg').readAsBytes();
    street = await File('test/fixtures/route/wukang.png').readAsBytes();
  });
  Future<(GoRouter, _Repo, _Store)> pump(
      WidgetTester tester, String page, double width,
      {double height = 1100,
      int photos = 1,
      Map<String, dynamic>? draftData}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo(photo, street)..photoCount = photos;
    final store = _Store();
    if (draftData != null) store.values['community_draft_user-a'] = draftData;
    final router = GoRouter(initialLocation: page, routes: [
      GoRoute(
          path: '/',
          builder: (_, s) => s.uri.queryParameters['tab'] == 'companion'
              ? Text(
                  'target:${s.uri.queryParameters['route']}:${s.uri.queryParameters['fragment']}')
              : const NotesPage()),
      GoRoute(
          path: '/community/post/:id',
          builder: (_, s) => NoteDetailPage(
              postId: s.pathParameters['id']!,
              photoIndex:
                  int.tryParse(s.uri.queryParameters['photo'] ?? '') ?? 0)),
      GoRoute(
          path: '/community/write',
          builder: (_, s) =>
              NoteComposePage(fragmentId: s.uri.queryParameters['fragment'])),
    ]);
    addTearDown(router.dispose);
    Future<void> mount() async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user-a'),
            notesLocationProvider.overrideWith(_Location.new),
            notesNowProvider.overrideWithValue(() => DateTime(2026, 10, 4)),
            experienceRepositoryProvider.overrideWithValue(repo),
            tourStoreProvider.overrideWithValue(store),
            activeTourControllerProvider.overrideWith(_Tour.new)
          ],
          child: RepaintBoundary(
              key: const ValueKey('screen'),
              child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  routerConfig: router,
                  theme: AppTheme.light))));
    }

    if (draftData != null) {
      await tester.runAsync(() async {
        for (final path
            in (draftData['photos'] as List? ?? []).whereType<String>()) {
          final completer = Completer<void>();
          final stream =
              FileImage(File(path)).resolve(const ImageConfiguration());
          final listener = ImageStreamListener((_, __) {
            if (!completer.isCompleted) completer.complete();
          },
              onError: (Object e, StackTrace? trace) =>
                  completer.completeError(e, trace));
          stream.addListener(listener);
          await completer.future;
          stream.removeListener(listener);
        }
        await mount();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
    } else {
      await mount();
    }
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
          MemoryImage(photo), tester.element(find.byType(Scaffold).first));
      await precacheImage(
          MemoryImage(street), tester.element(find.byType(Scaffold).first));
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return (router, repo, store);
  }

  for (final width in [390.0, 360.0, 320.0]) {
    for (final page in ['feed', 'cities', 'detail', 'compose']) {
      testWidgets('v7 $page ${width.toInt()}', (tester) async {
        await pump(
            tester,
            page == 'detail'
                ? '/community/post/sea'
                : page == 'compose'
                    ? '/community/write?fragment=dameisha-0'
                    : '/',
            width,
            height: page == 'detail' ? 1300 : 1100);
        if (page == 'cities') {
          await tester.tap(find.byKey(const ValueKey('notes-filter-0')));
          await tester.pumpAndSettle();
        }
        expect(find.text('在地记录'), findsNothing);
        expect(find.text('旅人分享'), findsNothing);
        expect(tester.takeException(), isNull);
        await expectLater(find.byKey(const ValueKey('screen')),
            matchesGoldenFile('goldens/v7-$page-${width.toInt()}.png'));
      });
    }
  }
  testWidgets('all cities filters, detail comments and exact place handoff',
      (tester) async {
    final (router, repo, _) = await pump(tester, '/', 390);
    expect(repo.cityCalls.toSet(), {null});
    await tester.tap(find.byKey(const ValueKey('notes-filter-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上海'));
    await tester.pumpAndSettle();
    expect(repo.cityCalls.last, 'shanghai');
    expect(find.text('转过街角，刚好遇见树影。'), findsOneWidget);
    expect(find.text('坐在海边，等天色慢下来。'), findsNothing);
    await tester.tap(find.text('全部城市').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('坐在海边，等天色慢下来。'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteDetailPage), findsOneWidget);
    expect(find.text('一个人去，沿海边慢慢走也很舒服。'), findsOneWidget);
    await tester.ensureVisible(find.text('去随行'));
    await tester.tap(find.text('去随行'));
    await tester.pumpAndSettle();
    expect(
        router.routeInformationProvider.value.uri.queryParameters['fragment'],
        'dameisha-0');
  });
  testWidgets('draft survives reopening and publish uses selected place',
      (tester) async {
    final (router, repo, store) =
        await pump(tester, '/community/write?fragment=dameisha-0', 390);
    await tester.enterText(
        find.byKey(const ValueKey('note-compose-body')), '风吹过来的时候，想在这里多坐一会儿。');
    await tester.tap(find.text('存草稿'));
    await tester.pumpAndSettle();
    expect(store.values['community_draft_user-a']?['body'], contains('风吹'));
    router.go('/');
    await tester.pumpAndSettle();
    router.push('/community/write');
    await tester.pumpAndSettle();
    expect(find.text('风吹过来的时候，想在这里多坐一会儿。'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('note-publish')));
    await tester.tap(find.byKey(const ValueKey('note-publish')));
    await tester.pumpAndSettle();
    expect(repo.publishedFragment, 'dameisha-0');
    expect(repo.draft?.category, CommunityCategory.onSite);
    expect(store.values['community_draft_user-a'], isEmpty);
    expect(router.routeInformationProvider.value.uri.queryParameters['tab'],
        'community');
  });

  for (final count in [2, 4, 9]) {
    testWidgets(
        'multi-photo $count collage opens selected image and supports gallery',
        (tester) async {
      await pump(tester, '/', 390, photos: count);
      await expectLater(find.byKey(const ValueKey('screen')),
          matchesGoldenFile('goldens/v14-feed-$count-390.png'));
      final selected = count == 2 ? 1 : 2;
      await tester.tap(find.byWidgetPredicate((w) =>
          w is NoteButton && w.label == '查看第 ${selected + 1} 张照片，共 $count 张'));
      await tester.pumpAndSettle();
      final gallery = find.byType(NoteGallery);
      expect(tester.widget<NoteGallery>(gallery).initialIndex, selected);
      await tester.tap(find.bySemanticsLabel('第 $count 张照片'));
      await tester.pumpAndSettle();
      expect(
          tester.widget<PageView>(find.byType(PageView).first).controller!.page,
          count - 1);
      await expectLater(find.byKey(const ValueKey('screen')),
          matchesGoldenFile('goldens/v14-detail-$count-390.png'));
      await tester.tap(find.bySemanticsLabel('查看大图').first);
      await tester.pumpAndSettle();
      expect(tester.widget<NoteGallery>(find.byType(NoteGallery).last).expanded,
          isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 360.0]) {
    testWidgets('nine photo detail at $width keeps all thumbnails visible',
        (tester) async {
      await pump(tester, '/community/post/sea?photo=8', width,
          photos: 9, height: 1300);
      expect(find.bySemanticsLabel('第 9 张照片'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('screen')),
          matchesGoldenFile('goldens/v14-detail-9-${width.toInt()}.png'));
    });
  }
  testWidgets('type filter applies while panel stays open', (tester) async {
    final (_, repo, _) = await pump(tester, '/', 390);
    await tester.tap(find.byKey(const ValueKey('notes-filter-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拍照机位'));
    await tester.pumpAndSettle();
    expect(repo.queries.last.category, CommunityCategory.viewpoint);
    expect(find.text('经验分享'), findsOneWidget);
    expect(find.text('收起 ↑'), findsOneWidget);
  });
  testWidgets(
      'nine-photo draft reorders and publishes selected category and media order',
      (tester) async {
    late Directory dir;
    late List<String> paths;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('jiandi-photo-test-');
      paths = [];
      for (var i = 0; i < 9; i++) {
        final file = File('${dir.path}/$i.jpg');
        await file.writeAsBytes(photo);
        paths.add(file.path);
      }
    });
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final (_, repo, store) = await pump(
        tester, '/community/write?fragment=dameisha-0', 390,
        height: 1400,
        draftData: {
          'body': '坐在海边，等天色慢下来。',
          'fragment': place.fragmentId,
          'category': 'experience',
          'photos': paths
        });
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(find.text('9 / 9'), findsOneWidget);
    expect(find.bySemanticsLabel('添加照片'), findsNothing);
    await tester.tap(find.bySemanticsLabel('编辑第 9 张照片'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('设为首图'));
    await tester.tap(find.text('设为首图'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('存草稿'));
    await tester.tap(find.text('存草稿'));
    await tester.pumpAndSettle();
    final saved = store.values['community_draft_user-a']!;
    expect((saved['photos'] as List).first, paths.last);
    expect(saved['category'], 'experience');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const ValueKey('screen')),
        matchesGoldenFile('goldens/v14-compose-nine-390.png'));
    await tester.ensureVisible(find.byKey(const ValueKey('note-publish')));
    await tester.tap(find.byKey(const ValueKey('note-publish')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    expect(repo.draft!.category, CommunityCategory.experience);
    expect(repo.draft!.photoPaths, saved['photos']);
  });
  testWidgets('leaving an edited note offers to preserve its draft',
      (tester) async {
    final (router, _, store) =
        await pump(tester, '/community/write?fragment=dameisha-0', 390);
    await tester.enterText(
        find.byKey(const ValueKey('note-compose-body')), '留住今天的海风');
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(find.text('把这则见闻留下？'), findsOneWidget);
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();
    expect(store.values['community_draft_user-a']?['body'], '留住今天的海风');
    expect(router.routeInformationProvider.value.uri.queryParameters['tab'],
        'community');
  });
  testWidgets('saving and removing a note updates the saved feed',
      (tester) async {
    await pump(tester, '/', 390);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(NotesPage)));
    expect((await container.read(savedNotesProvider.future)).items, isEmpty);
    await tester.tap(find.text('收藏').first);
    await tester.pumpAndSettle();
    expect((await container.read(savedNotesProvider.future)).items.single.id,
        'sea');
    await tester.tap(find.text('已收藏'));
    await tester.pumpAndSettle();
    expect((await container.read(savedNotesProvider.future)).items, isEmpty);
  });
  test('late city pagination cannot mix posts into another city', () async {
    final repo = _Repo(Uint8List(0), Uint8List(0));
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue('a'),
      notesLocationProvider.overrideWith(_Location.new),
      experienceRepositoryProvider.overrideWithValue(repo)
    ]);
    addTearDown(container.dispose);
    await container.read(notesLocationProvider.future);
    final subscription = container.listen(notesFeedProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(notesFeedProvider.future);
    repo.pendingPage = Completer<CommunityPage<CommunityPost>>();
    final pending = container.read(notesFeedProvider.notifier).loadMore();
    container.read(notesCityProvider.notifier).select('shanghai');
    final city = await container.read(notesFeedProvider.future);
    expect(city.items.single.place?.citySlug, 'shanghai');
    repo.pendingPage!.complete(CommunityPage(items: [fixturePost()]));
    await pending;
    expect(
        container
            .read(notesFeedProvider)
            .requireValue
            .items
            .single
            .place
            ?.citySlug,
        'shanghai');
  });
}

class _Repo extends DemoExperienceRepository {
  _Repo(this.photo, this.street);
  final Uint8List photo, street;
  int photoCount = 1;
  final saved = <String>{};
  final queries = <CommunityQuery>[];
  Completer<CommunityPage<CommunityPost>>? pendingPage;
  final cityCalls = <String?>[];
  String? publishedFragment;
  CommunityPostDraft? draft;
  @override
  Future<List<CommunityPlace>> communityPlaces() async => [place, shanghai];
  @override
  Future<CommunityPage<CommunityPost>> discoverCommunity(
      {String? citySlug,
      String? cursor,
      int limit = 12,
      CommunityQuery query = const CommunityQuery()}) async {
    cityCalls.add(citySlug);
    queries.add(query);
    if (cursor != null && pendingPage != null) return pendingPage!.future;
    final posts = [
      fixturePost(photos: photoCount),
      CommunityPost(
          id: 'street',
          fragmentId: shanghai.fragmentId,
          category: CommunityCategory.onSite,
          author: const CommunityAuthor(displayName: '小舟', avatar: 'default'),
          media: const [
            CommunityMedia(
                id: 'street-photo',
                url: '/community-media/street-photo',
                mimeType: 'image/png',
                width: 800,
                height: 800,
                position: 0)
          ],
          likeCount: 18,
          commentCount: 1,
          viewerHasLiked: false,
          viewerIsAuthor: false,
          createdAt: DateTime(2026, 10, 3, 15, 8),
          place: shanghai,
          title: '转过街角，刚好遇见树影。',
          body: '沿着武康路慢慢走，有些风景就在抬头的一瞬间。')
    ];
    return CommunityPage(
        items: posts
            .where((p) =>
                (citySlug == null || p.place?.citySlug == citySlug) &&
                (!query.savedOnly || saved.contains(p.id)))
            .map((p) => p.copyWith(viewerHasSaved: saved.contains(p.id)))
            .toList(),
        nextCursor: citySlug == null ? 'next' : null);
  }

  @override
  Future<void> setCommunitySaved(String id, bool value) async {
    if (value) {
      saved.add(id);
    } else {
      saved.remove(id);
    }
  }

  @override
  Future<CommunityPostDetail> communityPost(String id) async =>
      fixturePost(detail: true, photos: photoCount);
  @override
  Future<CommunityPage<CommunityAuthor>> communityLikers(String id,
          {String? cursor, int limit = 20}) async =>
      const CommunityPage(items: []);
  @override
  Future<CommunityPage<CommunityComment>> communityComments(String id,
          {String? cursor, int limit = 20}) async =>
      CommunityPage(items: [
        comment('c1', '小满', '一个人去，沿海边慢慢走也很舒服。',
            replies: [comment('r1', '阿岚', '是的，坐着看海也很好。')]),
        comment('c2', '周周', '喜欢这种不用把行程排满的下午。')
      ]);
  @override
  Future<Uint8List> communityMediaBytes(CommunityMedia media) async =>
      media.id == 'street-photo' ? street : photo;
  @override
  Future<CommunityPostDetail> shareCommunityPost(
      String fragmentId, CommunityPostDraft value) async {
    publishedFragment = fragmentId;
    draft = value;
    return fixturePost();
  }
}

class _Tour extends ActiveTourController {
  @override
  ActiveTourState build() => const ActiveTourState();
}

class _Store implements TourStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> readJson(String key) async => values[key];
  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Location extends NotesLocation {
  @override
  Future<DiscoveryLocationSample?> build() async => null;
}
