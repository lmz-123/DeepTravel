import 'dart:typed_data';

import '../domain/community_models.dart';
import '../domain/experience_repository.dart';
import '../domain/models.dart';
import '../domain/home_story.dart';
import '../domain/fragment_models.dart';
import 'demo_content.dart';

class DemoExperienceRepository implements ExperienceRepository {
  DemoExperienceRepository({this.latency = const Duration(milliseconds: 180)});

  final Duration latency;
  JourneySession? _journey;
  final Map<String, AnswerFeedback> _answers = {};
  final List<CommunityPost> _communityPosts = [];
  final Map<String, List<CommunityComment>> _communityComments = {};

  @override
  Future<HomeStory> randomHomeStory({
    String? citySlug,
    String? excludeId,
  }) async {
    await _pause();
    return const HomeStory(
      id: 'demo-home-story',
      arcId: 'demo-arc',
      title: '城墙今天想说点什么',
      introduction: '给自己三分钟，听一阵海风如何吹进一座老城。',
      coverImage: '',
      duration: Duration(minutes: 3),
      transcript: '这是演示模式的完整故事。连接正式服务后，这里会播放后台审核发布的城市故事。',
      audioUrl: '',
      cityName: '深圳',
      citySlug: 'shenzhen',
      routeTitle: '南头古城',
      routeSlug: 'nantou-ancient-city',
      narratorName: '见地讲述者',
    );
  }

  Future<void> _pause() => Future<void>.delayed(latency);

  @override
  Future<List<CityExperience>> cities() async {
    await _pause();
    return const [
      CityExperience(
        id: 'demo-shenzhen',
        slug: 'shenzhen',
        name: '深圳',
        subtitle: '在快速生长的城市里，寻找时间的叠层',
        heroImage: '',
      ),
      CityExperience(
        id: 'demo-shanghai',
        slug: 'shanghai',
        name: '上海',
        subtitle: '从街角开始，读懂城市的层次',
        heroImage: '',
      ),
    ];
  }

  @override
  Future<CityDiscoveryCatalog> discoveryForCity(String citySlug) async {
    await _pause();
    return CityDiscoveryCatalog(
      routes: const [demoRoute],
      scenicSpots: demoRoute.stops
          .map(
            (stop) => ScenicSpot(
              id: stop.id,
              title: stop.title,
              latitude: stop.latitude,
              longitude: stop.longitude,
              experienceTags: const [],
              routeId: demoRoute.id,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<RouteExperience> featuredRoute(String citySlug) async {
    final routes = (await discoveryForCity(citySlug)).routes;
    return routes.first;
  }

  @override
  Future<RouteExperience> routeBySlug(String slug) async {
    await _pause();
    if (slug != demoRoute.slug) throw StateError('路线不存在');
    return demoRoute;
  }

  @override
  Future<JourneySession> startOrResume(String routeId) async {
    await _pause();
    if (_journey != null && !_journey!.isCompleted) return _journey!;
    _answers.clear();
    _journey = JourneySession(
      id: 'demo-journey',
      routeId: routeId,
      status: 'active',
      currentStopPosition: 1,
      arrivedStopId: null,
      answeredStopIds: const {},
      progress: 0,
    );
    return _journey!;
  }

  @override
  Future<JourneySession> arrive(String journeyId) async {
    await _pause();
    final journey = _requireJourney(journeyId);
    final stop = demoRoute.stops[journey.currentStopPosition - 1];
    _journey = journey.copyWith(arrivedStopId: stop.id);
    return _journey!;
  }

  @override
  Future<AnswerFeedback> answer(
    String journeyId,
    String stopId,
    int selectedOption,
  ) async {
    await _pause();
    final journey = _requireJourney(journeyId);
    if (_answers.containsKey(stopId)) return _answers[stopId]!;
    final stop = demoRoute.stops.firstWhere((item) => item.id == stopId);
    if (journey.arrivedStopId != stopId) throw StateError('请先到达站点');
    final isCorrect = selectedOption == stop.challenge.correctOption;
    final feedback = AnswerFeedback(
      stopId: stopId,
      selectedOption: selectedOption,
      isCorrect: isCorrect,
      explanation: isCorrect
          ? '你观察到了关键线索。地点的形态，往往比一串年代更容易被记住。'
          : '再看一眼现场关系。重要的不是猜中，而是发现刚才忽略的细节。',
      insight: stop.insight,
    );
    _answers[stopId] = feedback;
    final answered = {...journey.answeredStopIds, stopId};
    _journey = journey.copyWith(
      answeredStopIds: answered,
      progress: answered.length / demoRoute.stops.length,
    );
    return feedback;
  }

  @override
  Future<JourneySession> advance(String journeyId) async {
    await _pause();
    final journey = _requireJourney(journeyId);
    final stop = demoRoute.stops[journey.currentStopPosition - 1];
    if (!journey.answeredStopIds.contains(stop.id)) throw StateError('请先完成观察');
    if (journey.currentStopPosition == demoRoute.stops.length) {
      _journey = journey.copyWith(
        status: 'completed',
        clearArrival: true,
        progress: 1,
      );
    } else {
      _journey = journey.copyWith(
        currentStopPosition: journey.currentStopPosition + 1,
        clearArrival: true,
      );
    }
    return _journey!;
  }

  @override
  Future<JourneyRecap> recap(String journeyId) async {
    await _pause();
    final journey = _requireJourney(journeyId);
    if (!journey.isCompleted) throw StateError('旅程尚未完成');
    return JourneyRecap(
      route: demoRoute,
      insights: demoRoute.stops.map((stop) {
        final answer = _answers[stop.id]!;
        return RecapInsight(
          stopId: stop.id,
          title: stop.title,
          insight: stop.insight,
          isCorrect: answer.isCorrect,
        );
      }).toList(),
    );
  }

  @override
  Future<List<JourneyLibraryItem>> journeys({String? status}) async {
    await _pause();
    final journey = _journey;
    if (journey == null || status != null && journey.status != status) {
      return const [];
    }
    return [
      JourneyLibraryItem(
        journey: journey,
        route: demoRoute,
        journeyKind: 'legacy',
        collectedCount: journey.answeredStopIds.length,
        totalCount: demoRoute.stops.length,
        evidenceCount: 0,
      ),
    ];
  }

  @override
  Future<JourneyContext> journeyContext(String journeyId) async =>
      JourneyContext(
        journey: _requireJourney(journeyId),
        route: demoRoute,
        journeyKind: 'legacy',
        collectedCount: _journey!.answeredStopIds.length,
        totalCount: demoRoute.stops.length,
      );

  @override
  Future<List<EvidenceRecord>> evidence(String journeyId) async => const [];

  @override
  Future<Uint8List> evidenceBytes(
          String journeyId, EvidenceRecord evidence) async =>
      _fragmentOnly();

  @override
  Future<void> deleteEvidence(String journeyId, String evidenceId) async =>
      _fragmentOnly();

  @override
  Future<EvidencePolicy> evidencePolicy() async => const EvidencePolicy(
        uploadEnabled: false,
        retentionDays: 0,
        maxBytes: 0,
        maxEdgePixels: 0,
        allowedMimeTypes: [],
        privateAccess: true,
        exifRemoved: true,
        normalizedOnUpload: true,
      );

  Never _fragmentOnly() => throw UnsupportedError('内置演示路线不支持碎片音频模式');

  @override
  Future<void> startActiveTour(String journeyId) async => _fragmentOnly();

  @override
  Future<void> stopActiveTour(String journeyId) async => _fragmentOnly();

  @override
  Future<StoryFragment> triggerFragment(String journeyId, String fragmentId,
          {required String method,
          required String idempotencyKey,
          double? latitude,
          double? longitude,
          double? accuracyM}) async =>
      _fragmentOnly();

  @override
  Future<StoryFragment> acknowledgePlayback(String journeyId, String fragmentId,
          double progress, String idempotencyKey) async =>
      _fragmentOnly();

  @override
  Future<EvidenceRecord> uploadEvidence(String journeyId, String fragmentId,
          String filePath, String idempotencyKey) async =>
      _fragmentOnly();

  @override
  Future<StoryLedger> ledger(String journeyId) async => _fragmentOnly();

  @override
  Future<ReconstructionResult> reconstruct(
          String journeyId, List<String> relationships) async =>
      _fragmentOnly();

  @override
  Future<FragmentRecap> fragmentRecap(String journeyId) async =>
      _fragmentOnly();

  @override
  Future<CommunityPolicy> communityPolicy() async => const CommunityPolicy(
        enabled: true,
        categories: CommunityCategory.values,
        titleMaxLength: 60,
        bodyMaxLength: 1200,
        commentMaxLength: 300,
        maxMedia: 4,
        allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        reportReasons: ['spam', 'abuse', 'privacy', 'misinformation', 'other'],
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
    await _pause();
    final filtered = _communityPosts
        .where((post) =>
            post.fragmentId == fragmentId &&
            (category == null || post.category == category))
        .take(limit)
        .toList(growable: false);
    return CommunityPage(items: filtered);
  }

  @override
  Future<CommunityPostDetail> communityPost(String postId) async =>
      _communityPosts.firstWhere((post) => post.id == postId);

  @override
  Future<CommunityPage<CommunityAuthor>> communityLikers(
    String postId, {
    String? cursor,
    int limit = 20,
  }) async =>
      const CommunityPage(items: []);

  @override
  Future<CommunityPage<CommunityComment>> communityComments(
    String postId, {
    String? cursor,
    int limit = 20,
  }) async =>
      CommunityPage(
          items: List.unmodifiable((_communityComments[postId] ?? const [])
              .where((item) => item.rootCommentId == null)));

  @override
  Future<CommunityPage<CommunityComment>> communityReplies(
    String rootCommentId, {
    String? cursor,
    int limit = 20,
  }) async {
    final comments = _communityComments.values.expand((items) => items);
    return CommunityPage(
      items: comments
          .where((item) => item.rootCommentId == rootCommentId)
          .take(limit)
          .toList(growable: false),
    );
  }

  @override
  Future<CommunityPostDetail> createCommunityPost(
    String journeyId,
    String fragmentId,
    CommunityPostDraft draft,
  ) async {
    await _pause();
    final existing = _communityPosts
        .where((post) => post.id == draft.idempotencyKey)
        .firstOrNull;
    if (existing != null) return existing;
    final post = CommunityPost(
      id: draft.idempotencyKey,
      fragmentId: fragmentId,
      category: draft.category,
      title: draft.title,
      body: draft.body ?? '',
      author: const CommunityAuthor(displayName: '演示旅行者', avatar: 'default'),
      media: const [],
      likeCount: 0,
      commentCount: 0,
      viewerHasLiked: false,
      viewerIsAuthor: true,
      createdAt: DateTime.now(),
    );
    _communityPosts.insert(0, post);
    return post;
  }

  @override
  Future<Uint8List> communityMediaBytes(CommunityMedia media) async =>
      Uint8List(0);

  @override
  Future<CommunityLikeResult> setCommunityLike(
      String postId, bool liked) async {
    final index = _communityPosts.indexWhere((post) => post.id == postId);
    final current = _communityPosts[index];
    final count = (current.likeCount + (liked ? 1 : -1)).clamp(0, 999999);
    _communityPosts[index] =
        current.copyWith(likeCount: count, viewerHasLiked: liked);
    return CommunityLikeResult(liked: liked, likeCount: count);
  }

  @override
  Future<CommunityComment> createCommunityComment(
    String postId,
    String body,
    String idempotencyKey, {
    String? replyToCommentId,
  }) async {
    final comments = _communityComments.putIfAbsent(postId, () => []);
    final existing =
        comments.where((item) => item.id == idempotencyKey).firstOrNull;
    if (existing != null) return existing;
    final replyTo = replyToCommentId == null
        ? null
        : comments.firstWhere((item) => item.id == replyToCommentId);
    final comment = CommunityComment(
      id: idempotencyKey,
      postId: postId,
      body: body,
      author: const CommunityAuthor(displayName: '演示旅行者', avatar: 'default'),
      viewerIsAuthor: true,
      createdAt: DateTime.now(),
      rootCommentId:
          replyTo == null ? null : (replyTo.rootCommentId ?? replyTo.id),
      replyToCommentId: replyToCommentId,
      replyTo: replyTo?.author,
    );
    comments.add(comment);
    final index = _communityPosts.indexWhere((post) => post.id == postId);
    _communityPosts[index] =
        _communityPosts[index].copyWith(commentCount: comments.length);
    return comment;
  }

  @override
  Future<void> deleteCommunityPost(String postId) async {
    _communityPosts.removeWhere((post) => post.id == postId);
  }

  @override
  Future<void> deleteCommunityComment(String commentId) async {
    for (final comments in _communityComments.values) {
      comments.removeWhere((comment) => comment.id == commentId);
    }
  }

  @override
  Future<void> reportCommunityPost(String postId, String reason) async {}

  @override
  Future<void> reportCommunityComment(String commentId, String reason) async {}

  JourneySession _requireJourney(String journeyId) {
    if (_journey == null || _journey!.id != journeyId) {
      throw StateError('旅程不存在');
    }
    return _journey!;
  }
}
