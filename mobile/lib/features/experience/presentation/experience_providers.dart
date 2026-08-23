import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logging/runtime_log_reporter.dart';
import '../data/api_experience_repository.dart';
import '../data/demo_experience_repository.dart';
import '../data/footprint_photo_picker.dart';
import '../data/footprint_share_service.dart';
import '../data/narration_voice_preference_repository.dart';
import '../data/pretrip_preparation_service.dart';
import '../data/user_preferences_repository.dart';
import '../domain/experience_repository.dart';
import '../domain/community_models.dart';
import '../domain/city_story.dart';
import '../domain/fragment_models.dart';
import '../domain/footprint_models.dart';
import '../domain/models.dart';
import '../../auth/presentation/auth_provider.dart';
import 'location_mode_controller.dart';

final dioProvider = Provider<Dio>((ref) {
  final reporter = ref.watch(runtimeLogReporterProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      contentType: Headers.jsonContentType,
    ),
  );
  dio.interceptors.add(InterceptorsWrapper(onError: (error, handler) {
    final uri = error.requestOptions.uri;
    reporter?.error(
      'network',
      '${error.requestOptions.method} ${uri.path} failed',
      error: error,
      context: {
        'status_code': error.response?.statusCode ?? 0,
        'failure_type': error.type.name,
        'host': uri.host,
      },
    );
    handler.next(error);
  }));
  return dio;
});

final experienceRepositoryProvider = Provider<ExperienceRepository>((ref) {
  if (AppConfig.mode == AppMode.api) {
    return ApiExperienceRepository(
      ref.watch(dioProvider),
      ref.watch(authRepositoryProvider),
      onUnauthorized: () => ref.read(authControllerProvider.notifier).expire(),
    );
  }
  return DemoExperienceRepository();
});

final footprintPhotoPickerProvider =
    Provider<FootprintPhotoPicker>((ref) => ImagePickerFootprintPhotoPicker());

final pretripPreparationServiceProvider = Provider<PretripPreparationService>(
  (ref) => PretripPreparationService(ref.watch(dioProvider)),
);

final currentUserIdProvider = Provider<String?>(
    (ref) => ref.watch(authControllerProvider).asData?.value?.user.id);

final travelerFavoritesProvider =
    FutureProvider.family<List<TravelerFavorite>, String>(
  (ref, userId) => ref.watch(experienceRepositoryProvider).favorites(),
);

final archivedActiveJourneysProvider =
    FutureProvider<List<ResumableJourney>>((ref) {
  final repository = ref.watch(experienceRepositoryProvider);
  if (repository is ApiExperienceRepository) {
    return repository.archivedActiveJourneys();
  }
  return const <ResumableJourney>[];
});

class UserJourneyFilter {
  const UserJourneyFilter(this.userId, {this.status});

  final String userId;
  final String? status;

  @override
  bool operator ==(Object other) =>
      other is UserJourneyFilter &&
      other.userId == userId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(userId, status);
}

class UserJourneyKey {
  const UserJourneyKey(this.userId, this.journeyId);

  final String userId;
  final String journeyId;

  @override
  bool operator ==(Object other) =>
      other is UserJourneyKey &&
      other.userId == userId &&
      other.journeyId == journeyId;

  @override
  int get hashCode => Object.hash(userId, journeyId);
}

class EvidenceBytesKey {
  const EvidenceBytesKey({
    required this.userId,
    required this.journeyId,
    required this.evidence,
  });

  final String userId;
  final String journeyId;
  final EvidenceRecord evidence;

  @override
  bool operator ==(Object other) =>
      other is EvidenceBytesKey &&
      other.userId == userId &&
      other.journeyId == journeyId &&
      other.evidence.id == evidence.id &&
      other.evidence.url == evidence.url;

  @override
  int get hashCode => Object.hash(userId, journeyId, evidence.id, evidence.url);
}

class FootprintPhotoBytesKey {
  const FootprintPhotoBytesKey(this.userId, this.footprintId, this.photo);
  final String userId;
  final String footprintId;
  final FootprintPhoto photo;

  @override
  bool operator ==(Object other) =>
      other is FootprintPhotoBytesKey &&
      other.userId == userId &&
      other.footprintId == footprintId &&
      other.photo.id == photo.id;

  @override
  int get hashCode => Object.hash(userId, footprintId, photo.id);
}

class CommunityFeedKey {
  const CommunityFeedKey(this.userId, this.journeyId, this.fragmentId);
  final String userId;
  final String journeyId;
  final String fragmentId;

  @override
  bool operator ==(Object other) =>
      other is CommunityFeedKey &&
      other.userId == userId &&
      other.journeyId == journeyId &&
      other.fragmentId == fragmentId;

  @override
  int get hashCode => Object.hash(userId, journeyId, fragmentId);
}

class CommunityPostKey {
  const CommunityPostKey(this.userId, this.postId);
  final String userId;
  final String postId;

  @override
  bool operator ==(Object other) =>
      other is CommunityPostKey &&
      other.userId == userId &&
      other.postId == postId;

  @override
  int get hashCode => Object.hash(userId, postId);
}

class CommunityMediaKey {
  const CommunityMediaKey(this.userId, this.media);
  final String userId;
  final CommunityMedia media;

  @override
  bool operator ==(Object other) =>
      other is CommunityMediaKey &&
      other.userId == userId &&
      other.media.id == media.id;

  @override
  int get hashCode => Object.hash(userId, media.id);
}

final journeyLibraryProvider =
    FutureProvider.family<List<JourneyLibraryItem>, UserJourneyFilter>(
  (ref, query) =>
      ref.watch(experienceRepositoryProvider).journeys(status: query.status),
);

final journeyContextProvider =
    FutureProvider.family<JourneyContext, UserJourneyKey>(
  (ref, key) =>
      ref.watch(experienceRepositoryProvider).journeyContext(key.journeyId),
);

final journeyEvidenceProvider =
    FutureProvider.family<List<EvidenceRecord>, UserJourneyKey>(
  (ref, key) => ref.watch(experienceRepositoryProvider).evidence(key.journeyId),
);

final evidenceBytesProvider =
    FutureProvider.family<Uint8List, EvidenceBytesKey>((ref, key) {
  return ref
      .watch(experienceRepositoryProvider)
      .evidenceBytes(key.journeyId, key.evidence);
});

final evidencePolicyProvider = FutureProvider.family<EvidencePolicy, String>(
  (ref, userId) => ref.watch(experienceRepositoryProvider).evidencePolicy(),
);

final communityPolicyProvider = FutureProvider.family<CommunityPolicy, String>(
  (ref, userId) => ref.watch(experienceRepositoryProvider).communityPolicy(),
);

final communityMediaBytesProvider =
    FutureProvider.autoDispose.family<Uint8List, CommunityMediaKey>(
  (ref, key) =>
      ref.watch(experienceRepositoryProvider).communityMediaBytes(key.media),
);

class CommunityFeedState {
  const CommunityFeedState({
    required this.policy,
    required this.items,
    this.category,
    this.nextCursor,
    this.isLoadingMore = false,
    this.mutationMessage,
  });
  final CommunityPolicy policy;
  final List<CommunityPostSummary> items;
  final CommunityCategory? category;
  final String? nextCursor;
  final bool isLoadingMore;
  final String? mutationMessage;
  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  CommunityFeedState copyWith({
    List<CommunityPostSummary>? items,
    CommunityCategory? category,
    bool clearCategory = false,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingMore,
    String? mutationMessage,
    bool clearMessage = false,
  }) =>
      CommunityFeedState(
        policy: policy,
        items: items ?? this.items,
        category: clearCategory ? null : category ?? this.category,
        nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        mutationMessage:
            clearMessage ? null : mutationMessage ?? this.mutationMessage,
      );
}

class CommunityFeedController extends AsyncNotifier<CommunityFeedState> {
  CommunityFeedController(this.key);
  final CommunityFeedKey key;
  int _generation = 0;

  ExperienceRepository get _repository =>
      ref.read(experienceRepositoryProvider);

  @override
  Future<CommunityFeedState> build() async {
    final generation = ++_generation;
    final values = await Future.wait<Object>([
      _repository.communityPolicy(),
      _repository.communityFeed(key.journeyId, key.fragmentId),
    ]);
    if (generation != _generation) throw StateError('节点已经切换');
    final policy = values[0] as CommunityPolicy;
    final page = values[1] as CommunityPage<CommunityPostSummary>;
    return CommunityFeedState(
      policy: policy,
      items: page.items,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    if (current == null) return ref.invalidateSelf();
    final generation = ++_generation;
    state = const AsyncLoading<CommunityFeedState>();
    state = await AsyncValue.guard(() async {
      final page = await _repository.communityFeed(
        key.journeyId,
        key.fragmentId,
        category: current.category,
      );
      if (generation != _generation) throw StateError('节点已经切换');
      return current.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
        clearMessage: true,
      );
    });
  }

  Future<void> selectCategory(CommunityCategory? category) async {
    final current = state.asData?.value;
    if (current == null || current.category == category) return;
    final generation = ++_generation;
    state = const AsyncLoading<CommunityFeedState>();
    state = await AsyncValue.guard(() async {
      final page = await _repository.communityFeed(
        key.journeyId,
        key.fragmentId,
        category: category,
      );
      if (generation != _generation) throw StateError('节点已经切换');
      return current.copyWith(
        category: category,
        clearCategory: category == null,
        items: page.items,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        clearMessage: true,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state =
        AsyncData(current.copyWith(isLoadingMore: true, clearMessage: true));
    try {
      final page = await _repository.communityFeed(
        key.journeyId,
        key.fragmentId,
        category: current.category,
        cursor: current.nextCursor,
      );
      final byId = <String, CommunityPostSummary>{
        for (final item in current.items) item.id: item,
        for (final item in page.items) item.id: item,
      };

      state = AsyncData(current.copyWith(
        items: byId.values.toList(growable: false),
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } catch (error) {
      state = AsyncData(current.copyWith(
        isLoadingMore: false,
        mutationMessage: _communityMessage(error),
      ));
    }
  }

  Future<bool> publish(CommunityPostDraft draft) async {
    final current = state.asData?.value;
    if (current == null) return false;
    try {
      final post = await _repository.createCommunityPost(
        key.journeyId,
        key.fragmentId,
        draft,
      );
      state = AsyncData(current.copyWith(
        items: [post, ...current.items.where((item) => item.id != post.id)],
        mutationMessage: '已发布到见地现场',
      ));
      return true;
    } catch (error) {
      state = AsyncData(
          current.copyWith(mutationMessage: _communityMessage(error)));
      return false;
    }
  }

  Future<void> toggleLike(CommunityPostSummary post) async {
    final current = state.asData?.value;
    if (current == null) return;
    final liked = !post.viewerHasLiked;
    final optimistic = post.copyWith(
      viewerHasLiked: liked,
      likeCount: (post.likeCount + (liked ? 1 : -1)).clamp(0, 999999),
    );
    state = AsyncData(current.copyWith(
      items: [
        for (final item in current.items)
          if (item.id == post.id) optimistic else item
      ],
      clearMessage: true,
    ));
    try {
      final result = await _repository.setCommunityLike(post.id, liked);
      final latest = state.asData?.value;
      if (latest == null) return;
      state = AsyncData(latest.copyWith(items: [
        for (final item in latest.items)
          if (item.id == post.id)
            item.copyWith(
              viewerHasLiked: result.liked,
              likeCount: result.likeCount,
            )
          else
            item,
      ]));
    } catch (error) {
      state = AsyncData(
          current.copyWith(mutationMessage: _communityMessage(error)));
    }
  }

  void removePost(String postId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      items: current.items
          .where((item) => item.id != postId)
          .toList(growable: false),
    ));
  }
}

final communityFeedControllerProvider = AsyncNotifierProvider.family
    .autoDispose<CommunityFeedController, CommunityFeedState, CommunityFeedKey>(
  CommunityFeedController.new,
);

class CommunityDetailState {
  const CommunityDetailState({
    required this.post,
    required this.likers,
    required this.comments,
    this.likerCursor,
    this.commentCursor,
    this.repliesByRoot = const {},
    this.replyCursorByRoot = const {},
    this.loadingReplyRoots = const {},
    this.isMutating = false,
    this.message,
  });
  final CommunityPostDetail post;
  final List<CommunityAuthor> likers;
  final List<CommunityComment> comments;
  final String? likerCursor;
  final String? commentCursor;
  final Map<String, List<CommunityComment>> repliesByRoot;
  final Map<String, String?> replyCursorByRoot;
  final Set<String> loadingReplyRoots;
  final bool isMutating;
  final String? message;

  CommunityDetailState copyWith({
    CommunityPostDetail? post,
    List<CommunityAuthor>? likers,
    List<CommunityComment>? comments,
    String? likerCursor,
    String? commentCursor,
    Map<String, List<CommunityComment>>? repliesByRoot,
    Map<String, String?>? replyCursorByRoot,
    Set<String>? loadingReplyRoots,
    bool? isMutating,
    String? message,
  }) =>
      CommunityDetailState(
        post: post ?? this.post,
        likers: likers ?? this.likers,
        comments: comments ?? this.comments,
        likerCursor: likerCursor ?? this.likerCursor,
        commentCursor: commentCursor ?? this.commentCursor,
        repliesByRoot: repliesByRoot ?? this.repliesByRoot,
        replyCursorByRoot: replyCursorByRoot ?? this.replyCursorByRoot,
        loadingReplyRoots: loadingReplyRoots ?? this.loadingReplyRoots,
        isMutating: isMutating ?? this.isMutating,
        message: message,
      );
}

class CommunityDetailController extends AsyncNotifier<CommunityDetailState> {
  CommunityDetailController(this.key);
  final CommunityPostKey key;
  ExperienceRepository get _repository =>
      ref.read(experienceRepositoryProvider);

  @override
  Future<CommunityDetailState> build() async {
    final values = await Future.wait<Object>([
      _repository.communityPost(key.postId),
      _repository.communityLikers(key.postId),
      _repository.communityComments(key.postId),
    ]);
    final likers = values[1] as CommunityPage<CommunityAuthor>;
    final comments = values[2] as CommunityPage<CommunityComment>;
    return CommunityDetailState(
      post: values[0] as CommunityPostDetail,
      likers: likers.items,
      comments: comments.items,
      likerCursor: likers.nextCursor,
      commentCursor: comments.nextCursor,
      repliesByRoot: {
        for (final root in comments.items) root.id: root.replyPreview,
      },
    );
  }

  Future<void> toggleLike() async {
    final current = state.asData?.value;
    if (current == null || current.isMutating) return;
    final intended = !current.post.viewerHasLiked;
    state = AsyncData(current.copyWith(
      post: current.post.copyWith(
        viewerHasLiked: intended,
        likeCount:
            (current.post.likeCount + (intended ? 1 : -1)).clamp(0, 999999),
      ),
      isMutating: true,
    ));
    try {
      final result = await _repository.setCommunityLike(key.postId, intended);
      final latest = state.requireValue;
      state = AsyncData(latest.copyWith(
        post: latest.post.copyWith(
          viewerHasLiked: result.liked,
          likeCount: result.likeCount,
        ),
        isMutating: false,
      ));
      ref.invalidate(communityFeedControllerProvider);
    } catch (error) {
      state = AsyncData(current.copyWith(message: _communityMessage(error)));
    }
  }

  Future<bool> comment(
    String body,
    String idempotencyKey, {
    CommunityComment? replyTo,
  }) async {
    final current = state.asData?.value;
    if (current == null || current.isMutating) return false;
    state = AsyncData(current.copyWith(isMutating: true));
    try {
      final comment = await _repository.createCommunityComment(
        key.postId,
        body,
        idempotencyKey,
        replyToCommentId: replyTo?.id,
      );
      final rootId =
          replyTo == null ? null : (replyTo.rootCommentId ?? replyTo.id);
      final replies = <String, List<CommunityComment>>{
        ...current.repliesByRoot,
      };
      var comments = current.comments;
      var inserted = false;
      if (rootId == null) {
        inserted = !current.comments.any((item) => item.id == comment.id);
        comments = [
          ...current.comments.where((item) => item.id != comment.id),
          comment,
        ];
      } else {
        final existing = replies[rootId] ?? const <CommunityComment>[];
        inserted = !existing.any((item) => item.id == comment.id);
        replies[rootId] = [
          ...existing.where((item) => item.id != comment.id),
          comment,
        ];
        comments = [
          for (final root in current.comments)
            if (root.id == rootId)
              root.copyWith(
                replyCount: root.replyCount +
                    (existing.any((item) => item.id == comment.id) ? 0 : 1),
                replyPreview: replies[rootId]!.take(2).toList(growable: false),
              )
            else
              root,
        ];
      }
      state = AsyncData(current.copyWith(
        post: current.post.copyWith(
          commentCount: current.post.commentCount + (inserted ? 1 : 0),
        ),
        comments: comments,
        repliesByRoot: replies,
        isMutating: false,
      ));
      ref.invalidate(communityFeedControllerProvider);
      return true;
    } catch (error) {
      state = AsyncData(current.copyWith(message: _communityMessage(error)));
      return false;
    }
  }

  Future<void> deleteComment(CommunityComment comment) async {
    final current = state.asData?.value;
    if (current == null) return;
    try {
      await _repository.deleteCommunityComment(comment.id);
      final rootId = comment.rootCommentId;
      final replies = <String, List<CommunityComment>>{
        ...current.repliesByRoot,
      };
      var comments = current.comments;
      if (rootId == null) {
        comments = [
          for (final root in current.comments)
            if (root.id == comment.id && root.replyCount > 0)
              root.copyWith(body: '', isTombstone: true)
            else if (root.id != comment.id)
              root,
        ];
      } else {
        replies[rootId] = (replies[rootId] ?? const [])
            .where((item) => item.id != comment.id)
            .toList(growable: false);
        comments = [
          for (final root in current.comments)
            if (root.id == rootId)
              root.copyWith(
                replyCount: (root.replyCount - 1).clamp(0, 999999),
                replyPreview: replies[rootId]!.take(2).toList(growable: false),
              )
            else
              root,
        ];
      }
      state = AsyncData(current.copyWith(
        post: current.post.copyWith(
          commentCount: (current.post.commentCount - 1).clamp(0, 999999),
        ),
        comments: comments,
        repliesByRoot: replies,
      ));
      ref.invalidate(communityFeedControllerProvider);
    } catch (error) {
      state = AsyncData(current.copyWith(message: _communityMessage(error)));
    }
  }

  Future<void> loadMoreComments() async {
    final current = state.asData?.value;
    if (current?.commentCursor == null || current!.isMutating) return;
    state = AsyncData(current.copyWith(isMutating: true));
    try {
      final page = await _repository.communityComments(
        key.postId,
        cursor: current.commentCursor,
      );
      final byId = {for (final item in current.comments) item.id: item};
      for (final item in page.items) {
        byId[item.id] = item;
      }
      state = AsyncData(CommunityDetailState(
        post: current.post,
        likers: current.likers,
        comments: byId.values.toList(growable: false),
        likerCursor: current.likerCursor,
        commentCursor: page.nextCursor,
        repliesByRoot: {
          ...current.repliesByRoot,
          for (final root in page.items) root.id: root.replyPreview,
        },
        replyCursorByRoot: current.replyCursorByRoot,
        loadingReplyRoots: current.loadingReplyRoots,
      ));
    } catch (error) {
      state = AsyncData(current.copyWith(
        isMutating: false,
        message: _communityMessage(error),
      ));
    }
  }

  Future<void> loadReplies(CommunityComment root, {bool more = false}) async {
    final current = state.asData?.value;
    if (current == null || current.loadingReplyRoots.contains(root.id)) return;
    final cursor = more ? current.replyCursorByRoot[root.id] : null;
    if (more && cursor == null) return;
    state = AsyncData(current.copyWith(
      loadingReplyRoots: {...current.loadingReplyRoots, root.id},
      message: null,
    ));
    try {
      final page = await _repository.communityReplies(
        root.id,
        cursor: cursor,
      );
      final latest = state.requireValue;
      final existing = more
          ? latest.repliesByRoot[root.id] ?? const <CommunityComment>[]
          : const <CommunityComment>[];
      final byId = <String, CommunityComment>{
        for (final item in existing) item.id: item,
        for (final item in page.items) item.id: item,
      };
      state = AsyncData(latest.copyWith(
        repliesByRoot: {
          ...latest.repliesByRoot,
          root.id: byId.values.toList(growable: false),
        },
        replyCursorByRoot: {
          ...latest.replyCursorByRoot,
          root.id: page.nextCursor,
        },
        loadingReplyRoots: {...latest.loadingReplyRoots}..remove(root.id),
      ));
    } catch (error) {
      final latest = state.requireValue;
      state = AsyncData(latest.copyWith(
        loadingReplyRoots: {...latest.loadingReplyRoots}..remove(root.id),
        message: _communityMessage(error),
      ));
    }
  }

  Future<void> loadMoreLikers() async {
    final current = state.asData?.value;
    if (current?.likerCursor == null || current!.isMutating) return;
    state = AsyncData(current.copyWith(isMutating: true));
    try {
      final page = await _repository.communityLikers(
        key.postId,
        cursor: current.likerCursor,
      );
      final names = <String>{};
      final merged = <CommunityAuthor>[];
      for (final item in [...current.likers, ...page.items]) {
        final identity = '${item.displayName}\u0000${item.avatar}';
        if (names.add(identity)) merged.add(item);
      }
      state = AsyncData(CommunityDetailState(
        post: current.post,
        likers: merged,
        comments: current.comments,
        likerCursor: page.nextCursor,
        commentCursor: current.commentCursor,
        repliesByRoot: current.repliesByRoot,
        replyCursorByRoot: current.replyCursorByRoot,
        loadingReplyRoots: current.loadingReplyRoots,
      ));
    } catch (error) {
      state = AsyncData(current.copyWith(
        isMutating: false,
        message: _communityMessage(error),
      ));
    }
  }
}

final communityDetailControllerProvider = AsyncNotifierProvider.family
    .autoDispose<CommunityDetailController, CommunityDetailState,
        CommunityPostKey>(
  CommunityDetailController.new,
);

String _communityMessage(Object error) =>
    error is ExperienceFailure ? error.message : '见地现场暂时没有响应，请稍后重试';

final orbPositionProvider =
    FutureProvider.family<NormalizedOrbPosition, String>((ref, userId) =>
        ref.watch(userPreferencesRepositoryProvider).readOrbPosition(userId));

class FootprintFilterController extends Notifier<FootprintFilter> {
  @override
  FootprintFilter build() => const FootprintFilter();

  void selectCity(String? slug) => state = FootprintFilter(
        citySlug: slug,
        theme: state.theme,
        journeyState: state.journeyState,
        organizationState: state.organizationState,
        month: state.month,
        order: state.order,
      );

  void selectTheme(String? theme) => state = FootprintFilter(
        citySlug: state.citySlug,
        theme: theme,
        journeyState: state.journeyState,
        organizationState: state.organizationState,
        month: state.month,
        order: state.order,
      );

  void selectJourneyState(String? value) => state = FootprintFilter(
        citySlug: state.citySlug,
        theme: state.theme,
        journeyState: value,
        organizationState: state.organizationState,
        month: state.month,
        order: state.order,
      );

  void selectOrganizationState(String? value) => state = FootprintFilter(
        citySlug: state.citySlug,
        theme: state.theme,
        journeyState: state.journeyState,
        organizationState: value,
        month: state.month,
        order: state.order,
      );

  void selectMonth(String? value) => state = FootprintFilter(
        citySlug: state.citySlug,
        theme: state.theme,
        journeyState: state.journeyState,
        organizationState: state.organizationState,
        month: value,
        order: state.order,
      );

  void selectOrder(String value) => state = FootprintFilter(
        citySlug: state.citySlug,
        theme: state.theme,
        journeyState: state.journeyState,
        organizationState: state.organizationState,
        month: state.month,
        order: value,
      );
}

final footprintFilterProvider =
    NotifierProvider<FootprintFilterController, FootprintFilter>(
        FootprintFilterController.new);

final currentFootprintsProvider = FutureProvider<FootprintPageResult>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const FootprintPageResult(
        items: [], cities: [], themes: [], months: [], total: 0);
  }
  return ref
      .watch(experienceRepositoryProvider)
      .footprints(ref.watch(footprintFilterProvider));
});

final currentFootprintResumeProvider =
    FutureProvider<FootprintEntry?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(experienceRepositoryProvider).footprintResumeCandidate();
});

class FootprintEditorController extends AsyncNotifier<FootprintEntry> {
  FootprintEditorController(this.footprintId);
  final String footprintId;

  ExperienceRepository get _repository =>
      ref.read(experienceRepositoryProvider);

  @override
  Future<FootprintEntry> build() => _repository.footprint(footprintId);

  Future<void> save(FootprintDraft draft) async {
    final previous = state.asData?.value;
    try {
      state = AsyncData(await _repository.updateFootprint(footprintId, draft));
      _invalidateCollections();
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> uploadPhoto(String path) async {
    final previous = state.asData?.value;
    try {
      await _repository.uploadFootprintPhoto(footprintId, path);
      state = AsyncData(await _repository.footprint(footprintId));
      _invalidateCollections();
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> deletePhoto() async {
    final previous = state.asData?.value;
    try {
      await _repository.deleteFootprintPhoto(footprintId);
      state = AsyncData(await _repository.footprint(footprintId));
      _invalidateCollections();
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  void _invalidateCollections() {
    ref.invalidate(currentFootprintsProvider);
    ref.invalidate(currentFootprintResumeProvider);
    ref.invalidate(footprintPhotoBytesProvider);
  }
}

final footprintEditorControllerProvider = AsyncNotifierProvider.family
    .autoDispose<FootprintEditorController, FootprintEntry, String>(
  FootprintEditorController.new,
);

final footprintRelatedContentProvider = FutureProvider.autoDispose
    .family<List<RelatedCityContent>, String>((ref, footprintId) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const <RelatedCityContent>[];
  return ref
      .watch(experienceRepositoryProvider)
      .footprintRelatedContent(footprintId);
});

final footprintPhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, FootprintPhotoBytesKey>((ref, key) => ref
        .watch(experienceRepositoryProvider)
        .footprintPhotoBytes(key.footprintId, key.photo));

final currentJourneyLibraryProvider =
    FutureProvider<List<JourneyLibraryItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const <JourneyLibraryItem>[];
  return ref.watch(
    journeyLibraryProvider(UserJourneyFilter(userId)).future,
  );
});

final currentAllJourneysProvider =
    FutureProvider<List<JourneyLibraryItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const <JourneyLibraryItem>[];
  return ref.watch(
    journeyLibraryProvider(UserJourneyFilter(userId)).future,
  );
});

final routeJourneyIndexProvider =
    FutureProvider<Map<String, JourneyLibraryItem>>((ref) async {
  final items = await ref.watch(currentAllJourneysProvider.future);
  final result = <String, JourneyLibraryItem>{};
  for (final item in items) {
    final current = result[item.route.id];
    if (current == null ||
        item.journey.status == 'active' && current.journey.status != 'active') {
      result[item.route.id] = item;
    }
  }
  return result;
});

void invalidatePrivateExperience(Ref ref) {
  ref.invalidate(journeyLibraryProvider);
  ref.invalidate(journeyContextProvider);
  ref.invalidate(journeyEvidenceProvider);
  ref.invalidate(evidenceBytesProvider);
  ref.invalidate(evidencePolicyProvider);
  ref.invalidate(communityPolicyProvider);
  ref.invalidate(communityMediaBytesProvider);
  ref.invalidate(communityFeedControllerProvider);
  ref.invalidate(communityDetailControllerProvider);
  ref.invalidate(currentJourneyLibraryProvider);
  ref.invalidate(currentAllJourneysProvider);
  ref.invalidate(routeJourneyIndexProvider);
  ref.invalidate(currentFootprintsProvider);
  ref.invalidate(currentFootprintResumeProvider);
  ref.invalidate(footprintEditorControllerProvider);
  ref.invalidate(footprintRelatedContentProvider);
  ref.invalidate(footprintPhotoBytesProvider);
}

void invalidatePrivateExperienceFromWidget(WidgetRef ref) {
  ref.invalidate(journeyLibraryProvider);
  ref.invalidate(journeyContextProvider);
  ref.invalidate(journeyEvidenceProvider);
  ref.invalidate(evidenceBytesProvider);
  ref.invalidate(evidencePolicyProvider);
  ref.invalidate(communityPolicyProvider);
  ref.invalidate(communityMediaBytesProvider);
  ref.invalidate(communityFeedControllerProvider);
  ref.invalidate(communityDetailControllerProvider);
  ref.invalidate(currentJourneyLibraryProvider);
  ref.invalidate(currentAllJourneysProvider);
  ref.invalidate(routeJourneyIndexProvider);
  ref.invalidate(currentFootprintsProvider);
  ref.invalidate(currentFootprintResumeProvider);
  ref.invalidate(footprintEditorControllerProvider);
  ref.invalidate(footprintRelatedContentProvider);
  ref.invalidate(footprintPhotoBytesProvider);
}

final privateExperienceLifecycleProvider = Provider<void>((ref) {
  ref.listen(authControllerProvider, (previous, next) {
    final previousId = previous?.asData?.value?.user.id;
    final nextId = next.asData?.value?.user.id;
    if (previousId != nextId) {
      invalidatePrivateExperience(ref);
      unawaited(
        ref.read(footprintShareServiceProvider).cleanup().catchError((_) {}),
      );
    }
  });
});

final routeProvider =
    FutureProvider.autoDispose.family<RouteExperience, String>((ref, slug) {
  return ref.watch(experienceRepositoryProvider).routeBySlug(slug);
});

final narrationVoicePreferenceRepositoryProvider =
    Provider<NarrationVoicePreferenceRepository>(
        (ref) => NarrationVoicePreferenceRepository());

final narrationVoicePreferenceProvider =
    FutureProvider.family<String?, NarrationVoicePreferenceKey>((ref, key) =>
        ref.watch(narrationVoicePreferenceRepositoryProvider).read(key));

final recapProvider =
    FutureProvider.family<JourneyRecap, String>((ref, journeyId) {
  return ref.watch(experienceRepositoryProvider).recap(journeyId);
});

class JourneyUiState {
  const JourneyUiState({
    this.route,
    this.session,
    this.feedback,
    this.isBusy = false,
    this.errorMessage,
  });

  final RouteExperience? route;
  final JourneySession? session;
  final AnswerFeedback? feedback;
  final bool isBusy;
  final String? errorMessage;

  JourneyUiState copyWith({
    RouteExperience? route,
    JourneySession? session,
    AnswerFeedback? feedback,
    bool clearFeedback = false,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) =>
      JourneyUiState(
        route: route ?? this.route,
        session: session ?? this.session,
        feedback: clearFeedback ? null : feedback ?? this.feedback,
        isBusy: isBusy ?? this.isBusy,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );
}

class JourneyController extends Notifier<JourneyUiState> {
  ExperienceRepository get _repository =>
      ref.read(experienceRepositoryProvider);

  @override
  JourneyUiState build() => const JourneyUiState();

  Future<String?> start(RouteExperience route) async {
    state = JourneyUiState(route: route, isBusy: true);
    try {
      final session = await _repository.startOrResume(route.id);
      state = JourneyUiState(route: route, session: session);
      return session.id;
    } catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: _message(error));
      return null;
    }
  }

  String resume(RouteExperience route, JourneySession session) {
    state = JourneyUiState(route: route, session: session);
    return session.id;
  }

  Future<void> arrive() async {
    final session = state.session;
    if (session == null) return;
    await _perform(() async {
      final updated = await _repository.arrive(session.id);
      state = state.copyWith(session: updated, isBusy: false, clearError: true);
    });
  }

  Future<void> answer(int selectedOption) async {
    final session = state.session;
    final route = state.route;
    if (session == null || route == null) return;
    final stop = route.stops[session.currentStopPosition - 1];
    await _perform(() async {
      final feedback = await _repository.answer(
        session.id,
        stop.id,
        selectedOption,
      );
      final answered = {...session.answeredStopIds, stop.id};
      state = state.copyWith(
        session: session.copyWith(
          answeredStopIds: answered,
          progress: answered.length / route.stops.length,
        ),
        feedback: feedback,
        isBusy: false,
        clearError: true,
      );
    });
  }

  Future<bool> advance() async {
    final session = state.session;
    if (session == null) return false;
    var completed = false;
    await _perform(() async {
      final updated = await _repository.advance(session.id);
      completed = updated.isCompleted;
      state = state.copyWith(
        session: updated,
        isBusy: false,
        clearFeedback: true,
        clearError: true,
      );
      ref.invalidate(journeyLibraryProvider);
      ref.invalidate(journeyContextProvider);
    });
    return completed;
  }

  Future<void> _perform(Future<void> Function() action) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await action();
    } catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: _message(error));
    }
  }

  String _message(Object error) {
    if (error is ExperienceFailure) return error.message;
    if (error is StateError) return error.message;
    return '刚才的操作没有完成，请再试一次';
  }
}

final journeyControllerProvider =
    NotifierProvider<JourneyController, JourneyUiState>(JourneyController.new);
