import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/experience/data/demo_experience_repository.dart';
import 'package:jiandi/features/experience/domain/community_models.dart';
import 'package:jiandi/features/experience/presentation/experience_providers.dart';

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

    final root = CommunityComment.fromJson({
      'id': 'root-1',
      'post_id': 'post-1',
      'body': '根评论',
      'author': {'display_name': '旅行者甲'},
      'reply_count': 1,
      'reply_preview': [
        {
          'id': 'reply-1',
          'post_id': 'post-1',
          'root_comment_id': 'root-1',
          'reply_to_comment_id': 'root-1',
          'body': '回复内容',
          'author': {'display_name': '旅行者乙'},
          'reply_to': {'display_name': '旅行者甲'},
        }
      ],
    });
    expect(root.replyCount, 1);
    expect(root.replyPreview.single.rootCommentId, 'root-1');
    expect(root.replyPreview.single.replyTo?.displayName, '旅行者甲');
  });

  test('late previous fragment feed cannot replace another fragment state',
      () async {
    final repository = _CommunityRepository(delayFirst: true);
    final container = ProviderContainer(overrides: [
      experienceRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    const firstKey = CommunityFeedKey('user-a', 'journey-1', 'fragment-1');
    const secondKey = CommunityFeedKey('user-a', 'journey-1', 'fragment-2');
    final firstSubscription = container.listen(
      communityFeedControllerProvider(firstKey),
      (_, __) {},
      fireImmediately: true,
    );
    final secondSubscription = container.listen(
      communityFeedControllerProvider(secondKey),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(firstSubscription.close);
    addTearDown(secondSubscription.close);

    final firstPending =
        container.read(communityFeedControllerProvider(firstKey).future);
    final second =
        await container.read(communityFeedControllerProvider(secondKey).future);
    expect(second.items.single.title, '第二节点现场');
    final first = await firstPending;
    expect(first.items.first.title, '城门转角的下午光线');
    final stillSecond =
        container.read(communityFeedControllerProvider(secondKey)).requireValue;
    expect(stillSecond.items.single.fragmentId, 'fragment-2');
    expect(stillSecond.items.single.title, '第二节点现场');
    expect(repository.feedCalls, 2);
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
}

class _CommunityRepository extends DemoExperienceRepository {
  _CommunityRepository({this.delayFirst = false})
      : super(latency: Duration.zero);
  final bool delayFirst;
  bool failLike = false;
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
}
