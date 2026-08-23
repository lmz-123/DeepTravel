import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/community_models.dart';
import '../domain/city_story.dart';
import '../domain/experience_repository.dart';
import '../domain/models.dart';
import '../domain/fragment_models.dart';
import '../domain/footprint_models.dart';
import '../domain/home_story.dart';

class ExperienceFailure implements Exception {
  const ExperienceFailure(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiExperienceRepository implements ExperienceRepository {
  ApiExperienceRepository(this._dio, this._auth, {this.onUnauthorized});

  final Dio _dio;
  final AuthRepository _auth;
  final Future<void> Function()? onUnauthorized;

  Future<void> _ensureAuth() async {
    if (_auth.token == null) {
      throw const ExperienceFailure('请先登录后再开始旅程');
    }
  }

  Options get _authorized =>
      Options(headers: {'Authorization': 'Bearer ${_auth.token}'});

  @override
  Future<List<CityExperience>> cities() async {
    final response = await _request(() => _dio.get('/cities'));
    return (response.data['data'] as List<dynamic>)
        .map((item) => CityExperience.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CityDiscoveryCatalog> discoveryForCity(String citySlug) async {
    final response = await _request(() => _dio.get('/cities/$citySlug/routes'));
    final data = response.data['data'] as Map<String, dynamic>;
    final summaries = data['routes'] as List<dynamic>;
    final routes = summaries
        .map((item) => RouteExperience.fromJson(item as Map<String, dynamic>))
        .toList();
    final published = routes
        .where((route) => route.contentStatus == 'published')
        .toList(growable: false);
    if (published.length != routes.length) {
      developer.log(
        'catalog_contract_warning: omitted non-published routes',
        name: 'jiandi.catalog',
      );
    }
    final routeIds = published.map((route) => route.id).toSet();
    final scenicSpots = (data['scenic_spots'] as List<dynamic>? ?? const [])
        .map((item) => ScenicSpot.fromJson(item as Map<String, dynamic>))
        .where((spot) => routeIds.contains(spot.routeId))
        .toList(growable: false);
    return CityDiscoveryCatalog(
      routes: published,
      scenicSpots: scenicSpots,
    );
  }

  @override
  Future<RouteExperience> featuredRoute(String citySlug) async {
    final routes = (await discoveryForCity(citySlug)).routes;
    if (routes.isEmpty) {
      throw const ExperienceFailure('这座城市还没有可用路线');
    }
    final summary = routes.firstWhere(
      (route) => route.isFeatured,
      orElse: () => routes.first,
    );
    return routeBySlug(summary.slug);
  }

  @override
  Future<RouteExperience> routeBySlug(String slug) async {
    final response = await _request(() => _dio.get('/routes/$slug'));
    final route = RouteExperience.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
    if (route.contentStatus != 'published') {
      developer.log(
        'catalog_contract_warning: rejected non-published route detail',
        name: 'jiandi.catalog',
      );
      throw const ExperienceFailure('这条路线尚未发布');
    }
    return route;
  }

  @override
  Future<HomeStory> randomHomeStory({
    String? citySlug,
    String? excludeId,
  }) async {
    final response = await _request(() => _dio.get(
          '/stories/random',
          queryParameters: {
            if (citySlug != null && citySlug.isNotEmpty) 'city_slug': citySlug,
            if (excludeId != null && excludeId.isNotEmpty)
              'exclude_id': excludeId,
          },
        ));
    return HomeStory.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<CityStoryHome> cityStoryHome(String citySlug) async {
    final response =
        await _request(() => _dio.get('/cities/$citySlug/stories'));
    return CityStoryHome.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<HomeStory> cityStory(String catalogId) async {
    final response = await _request(() => _dio.get('/city-stories/$catalogId'));
    return HomeStory.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<TravelerFavorite>> favorites() async {
    await _ensureAuth();
    final response =
        await _request(() => _dio.get('/favorites', options: _authorized));
    return (response.data['data'] as List<dynamic>)
        .whereType<Map>()
        .map((value) => TravelerFavorite.fromJson(
              Map<String, dynamic>.from(value),
            ))
        .toList(growable: false);
  }

  @override
  Future<TravelerFavorite> addFavorite(String kind, String targetId) async {
    await _ensureAuth();
    final response = await _request(
      () => _dio.put(
        '/favorites/$kind/${Uri.encodeComponent(targetId)}',
        options: _authorized,
      ),
    );
    return TravelerFavorite.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> removeFavorite(String kind, String targetId) async {
    await _ensureAuth();
    await _request(
      () => _dio.delete(
        '/favorites/$kind/${Uri.encodeComponent(targetId)}',
        options: _authorized,
      ),
    );
  }

  Future<List<ResumableJourney>> archivedActiveJourneys() async {
    await _ensureAuth();
    final response = await _request(
        () => _dio.get('/journeys/active', options: _authorized));
    return (response.data['data'] as List<dynamic>)
        .map(
          (item) => ResumableJourney.fromJson(item as Map<String, dynamic>),
        )
        .where((item) => item.route.contentStatus == 'archived')
        .toList(growable: false);
  }

  @override
  Future<JourneySession> startOrResume(String routeId) async {
    await _ensureAuth();
    final response = await _request(
      () => _dio.post('/journeys',
          data: {'route_id': routeId}, options: _authorized),
    );
    return JourneySession.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<JourneySession> arrive(String journeyId) async {
    final response = await _request(
      () => _dio.post(
        '/journeys/$journeyId/arrivals',
        data: {'demo': true},
        options: _authorized,
      ),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return JourneySession.fromJson(data['journey'] as Map<String, dynamic>);
  }

  @override
  Future<AnswerFeedback> answer(
    String journeyId,
    String stopId,
    int selectedOption,
  ) async {
    final response = await _request(
      () => _dio.post(
        '/journeys/$journeyId/answers',
        data: {'stop_id': stopId, 'selected_option': selectedOption},
        options: _authorized,
      ),
    );
    return AnswerFeedback.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<JourneySession> advance(String journeyId) async {
    final response = await _request(
      () => _dio.post('/journeys/$journeyId/advance', options: _authorized),
    );
    return JourneySession.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<JourneyRecap> recap(String journeyId) async {
    final response = await _request(
      () => _dio.get('/journeys/$journeyId/recap', options: _authorized),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final routeSummary = data['route'] as Map<String, dynamic>;
    final route = await routeBySlug(routeSummary['slug'] as String);
    final insights = (data['insights'] as List<dynamic>).map((item) {
      final value = item as Map<String, dynamic>;
      return RecapInsight(
        stopId: value['stop_id'] as String,
        title: value['title'] as String,
        insight: value['insight'] as String,
        isCorrect: value['is_correct'] as bool,
      );
    }).toList();
    return JourneyRecap(route: route, insights: insights);
  }

  @override
  Future<List<JourneyLibraryItem>> journeys({String? status}) async {
    await _ensureAuth();
    final response = await _request(
      () => _dio.get(
        '/journeys',
        queryParameters: {if (status != null) 'status': status},
        options: _authorized,
      ),
    );
    return (response.data['data'] as List<dynamic>)
        .map(
            (item) => JourneyLibraryItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<FootprintPageResult> footprints(FootprintFilter filter,
      {String? cursor}) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get(
          '/footprints',
          queryParameters: {
            if (filter.citySlug != null) 'city_slug': filter.citySlug,
            if (filter.theme != null) 'theme': filter.theme,
            if (filter.journeyState != null)
              'journey_state': filter.journeyState,
            if (filter.organizationState != null)
              'organization_state': filter.organizationState,
            if (filter.month != null) 'month': filter.month,
            if (cursor != null) 'cursor': cursor,
            'order': filter.order,
          },
          options: _authorized,
        ));
    return FootprintPageResult.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<FootprintEntry?> footprintResumeCandidate() async {
    await _ensureAuth();
    final response = await _request(
        () => _dio.get('/footprints/resume-candidate', options: _authorized));
    final value = response.data['data'];
    return value is Map<String, dynamic>
        ? FootprintEntry.fromJson(value)
        : null;
  }

  @override
  Future<FootprintEntry> footprint(String footprintId) async {
    await _ensureAuth();
    final response = await _request(
        () => _dio.get('/footprints/$footprintId', options: _authorized));
    return FootprintEntry.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<FootprintEntry> updateFootprint(
      String footprintId, FootprintDraft draft) async {
    await _ensureAuth();
    final response = await _request(() => _dio.patch(
          '/footprints/$footprintId',
          data: draft.toJson(),
          options: _authorized,
        ));
    return FootprintEntry.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<RelatedCityContent>> footprintRelatedContent(
      String footprintId) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get(
          '/footprints/$footprintId/related-content',
          options: _authorized,
        ));
    return (response.data['data'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(RelatedCityContent.fromJson)
        .toList(growable: false);
  }

  @override
  Future<FootprintPhoto> uploadFootprintPhoto(
      String footprintId, String filePath) async {
    await _ensureAuth();
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath),
      'idempotency_key': const Uuid().v4(),
    });
    final response = await _request(() => _dio.post(
          '/footprints/$footprintId/photo',
          data: form,
          options: _authorized,
        ));
    return FootprintPhoto.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<Uint8List> footprintPhotoBytes(
      String footprintId, FootprintPhoto photo) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get<List<int>>(
          _privateAssetPath(photo.url),
          options: _authorized.copyWith(responseType: ResponseType.bytes),
        ));
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  String _privateAssetPath(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    const prefix = '/api/v1';
    if (value.startsWith('$prefix/')) return value.substring(prefix.length);
    return value.startsWith('/') ? value : '/$value';
  }

  @override
  Future<void> deleteFootprintPhoto(String footprintId) async {
    await _ensureAuth();
    await _request(() =>
        _dio.delete('/footprints/$footprintId/photo', options: _authorized));
  }

  @override
  Future<JourneyContext> journeyContext(String journeyId) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get(
          '/journeys/$journeyId/context',
          options: _authorized,
        ));
    return JourneyContext.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<EvidenceRecord>> evidence(String journeyId) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get(
          '/journeys/$journeyId/evidence',
          options: _authorized,
        ));
    return (response.data['data'] as List<dynamic>)
        .map((item) => EvidenceRecord.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Uint8List> evidenceBytes(
      String journeyId, EvidenceRecord evidence) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get<List<int>>(
          _evidencePath(journeyId, evidence),
          options: _authorized.copyWith(responseType: ResponseType.bytes),
        ));
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  String _evidencePath(String journeyId, EvidenceRecord evidence) {
    final uri = Uri.tryParse(evidence.url);
    if (uri != null && uri.hasScheme) return evidence.url;
    const prefix = '/api/v1';
    if (evidence.url.startsWith('$prefix/')) {
      return evidence.url.substring(prefix.length);
    }
    if (evidence.url.startsWith('/')) return evidence.url;
    return '/journeys/$journeyId/evidence/${evidence.id}';
  }

  @override
  Future<void> deleteEvidence(String journeyId, String evidenceId) async {
    await _ensureAuth();
    await _request(() => _dio.delete(
          '/journeys/$journeyId/evidence/$evidenceId',
          options: _authorized,
        ));
  }

  @override
  Future<EvidencePolicy> evidencePolicy() async {
    await _ensureAuth();
    final response = await _request(
      () => _dio.get('/policies/evidence', options: _authorized),
    );
    return EvidencePolicy.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> startActiveTour(String journeyId) async {
    await _ensureAuth();
    await _request(() =>
        _dio.post('/journeys/$journeyId/active-tour', options: _authorized));
  }

  @override
  Future<void> stopActiveTour(String journeyId) async {
    await _ensureAuth();
    await _request(() =>
        _dio.delete('/journeys/$journeyId/active-tour', options: _authorized));
  }

  @override
  Future<StoryFragment> triggerFragment(
    String journeyId,
    String fragmentId, {
    required String method,
    required String idempotencyKey,
    double? latitude,
    double? longitude,
    double? accuracyM,
  }) async {
    await _ensureAuth();
    final response = await _request(() => _dio.post(
          '/journeys/$journeyId/fragments/$fragmentId/triggers',
          data: {
            'method': method,
            'idempotency_key': idempotencyKey,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (accuracyM != null) 'accuracy_m': accuracyM,
            'occurred_at': DateTime.now().toUtc().toIso8601String(),
          },
          options: _authorized,
        ));
    final data = response.data['data'] as Map<String, dynamic>;
    return StoryFragment.fromJson(data['fragment'] as Map<String, dynamic>);
  }

  @override
  Future<StoryFragment> acknowledgePlayback(String journeyId, String fragmentId,
      double progress, String idempotencyKey) async {
    await _ensureAuth();
    final response = await _request(() => _dio.post(
          '/journeys/$journeyId/fragments/$fragmentId/playback',
          data: {'progress': progress, 'idempotency_key': idempotencyKey},
          options: _authorized,
        ));
    final data = response.data['data'] as Map<String, dynamic>;
    return StoryFragment.fromJson(data['fragment'] as Map<String, dynamic>);
  }

  @override
  Future<EvidenceRecord> uploadEvidence(String journeyId, String fragmentId,
      String filePath, String idempotencyKey) async {
    await _ensureAuth();
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath),
      'idempotency_key': idempotencyKey,
      'captured_at': DateTime.now().toUtc().toIso8601String(),
    });
    final response = await _request(() => _dio.post(
          '/journeys/$journeyId/fragments/$fragmentId/evidence',
          data: form,
          options: _authorized.copyWith(
            contentType: 'multipart/form-data',
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 60),
          ),
        ));
    return EvidenceRecord.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<StoryLedger> ledger(String journeyId) async {
    await _ensureAuth();
    final response = await _request(
        () => _dio.get('/journeys/$journeyId/ledger', options: _authorized));
    return StoryLedger.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<ReconstructionResult> reconstruct(
      String journeyId, List<String> relationships) async {
    await _ensureAuth();
    final response = await _request(() => _dio.post(
        '/journeys/$journeyId/reconstruction',
        data: {'relationships': relationships},
        options: _authorized));
    return ReconstructionResult.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<FragmentRecap> fragmentRecap(String journeyId) async {
    await _ensureAuth();
    final response = await _request(
        () => _dio.get('/journeys/$journeyId/recap', options: _authorized));
    return FragmentRecap.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<CommunityPolicy> communityPolicy() async {
    await _ensureAuth();
    final response = await _request(
      () => _dio.get('/policies/community', options: _authorized),
    );
    return CommunityPolicy.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<CommunityPage<CommunityPostSummary>> communityFeed(
    String journeyId,
    String fragmentId, {
    CommunityCategory? category,
    String? cursor,
    int limit = 12,
  }) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get(
          '/journeys/$journeyId/fragments/$fragmentId/community-posts',
          queryParameters: {
            'limit': limit,
            if (category != null) 'category': category.id,
            if (cursor != null) 'cursor': cursor,
          },
          options: _authorized,
        ));
    return _communityPage(response.data['data'], CommunityPost.fromJson);
  }

  @override
  Future<CommunityPostDetail> communityPost(String postId) async {
    await _ensureAuth();
    final response = await _request(
      () => _dio.get('/community-posts/$postId', options: _authorized),
    );
    return CommunityPost.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<CommunityPage<CommunityAuthor>> communityLikers(
    String postId, {
    String? cursor,
    int limit = 20,
  }) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get(
          '/community-posts/$postId/likes',
          queryParameters: {
            'limit': limit,
            if (cursor != null) 'cursor': cursor,
          },
          options: _authorized,
        ));
    return _communityPage(response.data['data'], CommunityAuthor.fromJson);
  }

  @override
  Future<CommunityPage<CommunityComment>> communityComments(
    String postId, {
    String? cursor,
    int limit = 20,
  }) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get(
          '/community-posts/$postId/comments',
          queryParameters: {
            'limit': limit,
            if (cursor != null) 'cursor': cursor,
          },
          options: _authorized,
        ));
    return _communityPage(response.data['data'], CommunityComment.fromJson);
  }

  @override
  Future<CommunityPage<CommunityComment>> communityReplies(
    String rootCommentId, {
    String? cursor,
    int limit = 20,
  }) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get(
          '/community-comments/$rootCommentId/replies',
          queryParameters: {
            'limit': limit,
            if (cursor != null) 'cursor': cursor,
          },
          options: _authorized,
        ));
    return _communityPage(response.data['data'], CommunityComment.fromJson);
  }

  @override
  Future<CommunityPostDetail> createCommunityPost(
    String journeyId,
    String fragmentId,
    CommunityPostDraft draft,
  ) async {
    await _ensureAuth();
    final form = FormData();
    form.fields.addAll([
      MapEntry('category', draft.category.id),
      MapEntry('idempotency_key', draft.idempotencyKey),
      if (draft.title != null) MapEntry('title', draft.title!),
      if (draft.body != null) MapEntry('body', draft.body!),
      ...draft.evidenceIds.map((id) => MapEntry('evidence_ids[]', id)),
    ]);
    for (final path in draft.photoPaths) {
      form.files.add(MapEntry('photos[]', await MultipartFile.fromFile(path)));
    }
    final response = await _request(() => _dio.post(
          '/journeys/$journeyId/fragments/$fragmentId/community-posts',
          data: form,
          options: _authorized.copyWith(
            contentType: 'multipart/form-data',
            sendTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
          ),
        ));
    return CommunityPost.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<Uint8List> communityMediaBytes(CommunityMedia media) async {
    await _ensureAuth();
    final response = await _request(() => _dio.get<List<int>>(
          _privateMediaPath(media.url, '/community-media/${media.id}'),
          options: _authorized.copyWith(responseType: ResponseType.bytes),
        ));
    return Uint8List.fromList(response.data ?? const <int>[]);
  }

  @override
  Future<CommunityLikeResult> setCommunityLike(
      String postId, bool liked) async {
    await _ensureAuth();
    final response = await _request(() => liked
        ? _dio.put('/community-posts/$postId/like', options: _authorized)
        : _dio.delete('/community-posts/$postId/like', options: _authorized));
    return CommunityLikeResult.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<CommunityComment> createCommunityComment(
    String postId,
    String body,
    String idempotencyKey, {
    String? replyToCommentId,
  }) async {
    await _ensureAuth();
    final response = await _request(() => _dio.post(
          '/community-posts/$postId/comments',
          data: {
            'body': body,
            'idempotency_key': idempotencyKey,
            if (replyToCommentId != null)
              'reply_to_comment_id': replyToCommentId,
          },
          options: _authorized,
        ));
    return CommunityComment.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteCommunityPost(String postId) async {
    await _ensureAuth();
    await _request(
      () => _dio.delete('/community-posts/$postId', options: _authorized),
    );
  }

  @override
  Future<void> deleteCommunityComment(String commentId) async {
    await _ensureAuth();
    await _request(
      () => _dio.delete('/community-comments/$commentId', options: _authorized),
    );
  }

  @override
  Future<void> reportCommunityPost(String postId, String reason) async {
    await _ensureAuth();
    await _request(() => _dio.post(
          '/community-posts/$postId/reports',
          data: {'reason': reason},
          options: _authorized,
        ));
  }

  @override
  Future<void> reportCommunityComment(String commentId, String reason) async {
    await _ensureAuth();
    await _request(() => _dio.post(
          '/community-comments/$commentId/reports',
          data: {'reason': reason},
          options: _authorized,
        ));
  }

  CommunityPage<T> _communityPage<T>(
    Object? raw,
    T Function(Map<String, dynamic>) decode,
  ) {
    final data = raw as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => decode(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    return CommunityPage<T>(
      items: items,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  String _privateMediaPath(String value, String fallback) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    const prefix = '/api/v1';
    if (value.startsWith('$prefix/')) return value.substring(prefix.length);
    return value.startsWith('/') ? value : fallback;
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() action,
  ) async {
    try {
      return await action();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await onUnauthorized?.call();
        throw const ExperienceFailure(
          '登录已过期，请重新登录',
          code: 'unauthorized',
          statusCode: 401,
        );
      }
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final envelope = responseData['error'];
        if (envelope is Map<String, dynamic>) {
          throw ExperienceFailure(
            envelope['message'] as String? ?? '请求失败',
            code: envelope['code'] as String?,
            statusCode: error.response?.statusCode,
          );
        }
      }
      throw ExperienceFailure(
        '暂时无法连接见地服务，请检查网络后重试',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
