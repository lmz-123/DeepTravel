import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/community_models.dart';
import 'package:jiandi/features/experience/domain/fragment_models.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';
import 'package:jiandi/features/experience/presentation/widgets/node_community_section.dart';

void main() {
  test('community models defensively parse missing optional fields', () {
    final post = CommunityPost.fromJson({
      'id': 'post-1',
      'fragment_id': 'fragment-1',
      'category': 'fact_supplement',
      'author': {'display_name': '旅行者甲'},
      'media': <Object>[],
    });
    expect(post.category, CommunityCategory.factSupplement);
    expect(post.category.label, contains('旅行者内容'));
    expect(post.body, isEmpty);
    expect(post.likeCount, 0);
    expect(post.author.avatar, 'default');
  });

  testWidgets(
      'inline community renders text/image cards and opens contextual detail',
      (tester) async {
    final repository = _CommunityRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-a'),
        experienceRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: NodeCommunitySection(
                userId: 'user-a',
                journeyId: 'journey-1',
                fragment: _fragment,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('见地现场'), findsOneWidget);
    expect(find.text('城门转角的下午光线'), findsOneWidget);
    expect(find.text('雨后石板路比较滑，建议穿防滑鞋。'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.ensureVisible(find.text('城门转角的下午光线'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('城门转角的下午光线'));
    await tester.pumpAndSettle();
    final detailScroll = find.byKey(const ValueKey('community-detail-scroll'));
    expect(detailScroll, findsOneWidget);
    expect(
      find.descendant(
        of: detailScroll,
        matching: find.text('顺着榕树向东拍，砖缝的层次最清楚。'),
      ),
      findsOneWidget,
    );
    await tester.drag(detailScroll, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('现场回应'), findsOneWidget);
    expect(find.text('确实是好机位。'), findsOneWidget);

    await tester.ensureVisible(find.text('3 个赞'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 个赞'));
    await tester.pumpAndSettle();
    expect(repository.posts.first.viewerHasLiked, isTrue);
  });

  testWidgets('switching fragment cannot display a late previous feed',
      (tester) async {
    final repository = _CommunityRepository(delayFirst: true);
    late StateSetter setHostState;
    var fragment = _fragment;
    await tester.pumpWidget(ProviderScope(
      overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: StatefulBuilder(builder: (context, setState) {
          setHostState = setState;
          return Scaffold(
            body: NodeCommunitySection(
              userId: 'user-a',
              journeyId: 'journey-1',
              fragment: fragment,
            ),
          );
        }),
      ),
    ));
    await tester.pump();
    setHostState(() => fragment = _secondFragment);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('第二节点现场'), findsOneWidget);
    expect(find.text('城门转角的下午光线'), findsNothing);
  });

  test('optimistic like rolls back and account-scoped feeds stay isolated',
      () async {
    final repository = _CommunityRepository()..failLike = true;
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    const keyA = CommunityFeedKey('user-a', 'journey-1', 'fragment-1');
    const keyB = CommunityFeedKey('user-b', 'journey-2', 'fragment-1');
    final subscriptionA = container.listen(
      communityFeedControllerProvider(keyA),
      (_, __) {},
      fireImmediately: true,
    );
    final subscriptionB = container.listen(
      communityFeedControllerProvider(keyB),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscriptionA.close);
    addTearDown(subscriptionB.close);
    final stateA =
        await container.read(communityFeedControllerProvider(keyA).future);
    final stateB =
        await container.read(communityFeedControllerProvider(keyB).future);

    await container
        .read(communityFeedControllerProvider(keyA).notifier)
        .toggleLike(stateA.items.first);

    final rolledBack =
        container.read(communityFeedControllerProvider(keyA)).requireValue;
    final untouched =
        container.read(communityFeedControllerProvider(keyB)).requireValue;
    expect(rolledBack.items.first.likeCount, 3);
    expect(rolledBack.mutationMessage, isNotNull);
    expect(untouched.items.first.likeCount, stateB.items.first.likeCount);
    expect(identical(rolledBack, untouched), isFalse);
  });

  testWidgets('cancelling private evidence share creates no community post',
      (tester) async {
    final repository = _CommunityRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NodeCommunitySection(
              userId: 'user-a',
              journeyId: 'journey-1',
              fragment: _fragment,
              evidence: [
                EvidenceRecord(
                  id: 'evidence-1',
                  url: '/journeys/journey-1/evidence/evidence-1',
                  fragmentId: 'fragment-1',
                )
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('在这条线索下，留下你的发现…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '准备分享私人留念');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发布到见地现场'));
    await tester.pumpAndSettle();
    expect(find.text('分享到见地现场？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.createCalls, 0);
    expect(find.text('发布现场笔记'), findsOneWidget);
  });

  testWidgets('composer close responds after selecting a footprint photo',
      (tester) async {
    final repository = _CommunityRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NodeCommunitySection(
              userId: 'user-a',
              journeyId: 'journey-1',
              fragment: _fragment,
              evidence: [
                EvidenceRecord(
                  id: 'evidence-1',
                  url: '/journeys/journey-1/evidence/evidence-1',
                  fragmentId: 'fragment-1',
                )
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('在这条线索下，留下你的发现…'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    await tester.tap(find.byTooltip('关闭发布'));
    await tester.pumpAndSettle();
    expect(find.text('放弃这条现场笔记？'), findsOneWidget);
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    expect(find.text('发布现场笔记'), findsNothing);
    expect(repository.createCalls, 0);
  });

  testWidgets('locked node has no community surface or feed request',
      (tester) async {
    final repository = _CommunityRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [experienceRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        home: Scaffold(
          body: NodeCommunitySection(
            userId: 'user-a',
            journeyId: 'journey-1',
            fragment: _lockedFragment,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('见地现场'), findsNothing);
    expect(repository.feedCalls, 0);
  });
}

class _CommunityRepository extends DemoExperienceRepository {
  _CommunityRepository({this.delayFirst = false})
      : super(latency: Duration.zero);
  final bool delayFirst;
  bool failLike = false;
  int createCalls = 0;
  int feedCalls = 0;

  late final List<CommunityPost> posts = [
    CommunityPost(
      id: 'post-image',
      fragmentId: 'fragment-1',
      category: CommunityCategory.viewpoint,
      title: '城门转角的下午光线',
      body: '顺着榕树向东拍，砖缝的层次最清楚。',
      author: const CommunityAuthor(displayName: '旅行者甲', avatar: 'default'),
      media: const [
        CommunityMedia(
          id: 'media-1',
          url: '/api/v1/community-media/media-1',
          mimeType: 'image/png',
          width: 1,
          height: 1,
          position: 0,
        ),
      ],
      likeCount: 3,
      commentCount: 1,
      viewerHasLiked: false,
      viewerIsAuthor: false,
      createdAt: DateTime(2026, 8, 23),
    ),
    CommunityPost(
      id: 'post-text',
      fragmentId: 'fragment-1',
      category: CommunityCategory.experience,
      body: '雨后石板路比较滑，建议穿防滑鞋。',
      author: const CommunityAuthor(displayName: '旅行者乙', avatar: 'default'),
      media: const [],
      likeCount: 0,
      commentCount: 0,
      viewerHasLiked: false,
      viewerIsAuthor: true,
      createdAt: DateTime(2026, 8, 22),
    ),
    CommunityPost(
      id: 'post-second',
      fragmentId: 'fragment-2',
      category: CommunityCategory.onSite,
      title: '第二节点现场',
      author: const CommunityAuthor(displayName: '旅行者丙', avatar: 'default'),
      media: const [],
      likeCount: 0,
      commentCount: 0,
      viewerHasLiked: false,
      viewerIsAuthor: false,
      createdAt: DateTime(2026, 8, 23),
    ),
  ];

  @override
  Future<CommunityPolicy> communityPolicy() async => const CommunityPolicy(
        enabled: true,
        categories: CommunityCategory.values,
        titleMaxLength: 60,
        bodyMaxLength: 1200,
        commentMaxLength: 300,
        maxMedia: 4,
        allowedMimeTypes: ['image/jpeg', 'image/png'],
        reportReasons: ['other'],
        privateSourceRemainsPrivate: true,
        communityCopyIsIndependent: true,
      );

  @override
  Future<CommunityPage<CommunityPostSummary>> communityFeed(
    String journeyId,
    String fragmentId, {
    CommunityCategory? category,
    String? cursor,
    int limit = 12,
  }) async {
    feedCalls += 1;
    if (delayFirst && fragmentId == 'fragment-1') {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    return CommunityPage(
      items: posts
          .where((post) =>
              post.fragmentId == fragmentId &&
              (category == null || post.category == category))
          .toList(),
    );
  }

  @override
  Future<CommunityPostDetail> communityPost(String postId) async =>
      posts.firstWhere((post) => post.id == postId);

  @override
  Future<CommunityPage<CommunityAuthor>> communityLikers(
    String postId, {
    String? cursor,
    int limit = 20,
  }) async =>
      const CommunityPage(items: [
        CommunityAuthor(displayName: '旅行者乙', avatar: 'default'),
      ]);

  @override
  Future<CommunityPage<CommunityComment>> communityComments(
    String postId, {
    String? cursor,
    int limit = 20,
  }) async =>
      CommunityPage(items: [
        CommunityComment(
          id: 'comment-1',
          postId: postId,
          body: '确实是好机位。',
          author: const CommunityAuthor(displayName: '旅行者乙', avatar: 'default'),
          viewerIsAuthor: false,
          createdAt: DateTime(2026, 8, 23),
        ),
      ]);

  @override
  Future<Uint8List> communityMediaBytes(CommunityMedia media) async =>
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );

  @override
  Future<CommunityLikeResult> setCommunityLike(
      String postId, bool liked) async {
    if (failLike) throw StateError('offline');
    final index = posts.indexWhere((post) => post.id == postId);
    final current = posts[index];
    posts[index] = current.copyWith(
      viewerHasLiked: liked,
      likeCount: current.likeCount + (liked ? 1 : -1),
    );
    return CommunityLikeResult(liked: liked, likeCount: posts[index].likeCount);
  }

  @override
  Future<CommunityPostDetail> createCommunityPost(
    String journeyId,
    String fragmentId,
    CommunityPostDraft draft,
  ) async {
    createCalls += 1;
    return posts.first;
  }
}

const _trigger = TriggerRegion(
  latitude: 22.5,
  longitude: 114,
  entryRadiusM: 50,
  exitRadiusM: 80,
  maxAccuracyM: 35,
  qualifyingSamples: 2,
  sampleWindowSeconds: 15,
  cooldownSeconds: 120,
  auditState: 'reviewed',
);

const _audio = NarrationAsset(
  url: 'https://example.test/audio.m4a',
  mimeType: 'audio/mp4',
  sizeBytes: 1,
  scriptVersion: 'v1',
);

const _fragment = StoryFragment(
  id: 'fragment-1',
  position: 1,
  safePreview: '第一节点',
  interactionType: 'passive',
  reviewState: 'reviewed',
  triggerRegion: _trigger,
  audio: _audio,
  title: '第一节点',
  transcript: '已解锁',
  state: 'collected',
);

const _secondFragment = StoryFragment(
  id: 'fragment-2',
  position: 2,
  safePreview: '第二节点',
  interactionType: 'passive',
  reviewState: 'reviewed',
  triggerRegion: _trigger,
  audio: _audio,
  title: '第二节点',
  transcript: '已解锁',
  state: 'collected',
);

const _lockedFragment = StoryFragment(
  id: 'fragment-locked',
  position: 3,
  safePreview: '尚未解锁',
  interactionType: 'passive',
  reviewState: 'reviewed',
  triggerRegion: _trigger,
  audio: _audio,
);
