import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/experience_repository.dart';
import '../domain/models.dart';
import '../domain/fragment_models.dart';

class ExperienceFailure implements Exception {
  const ExperienceFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiExperienceRepository implements ExperienceRepository {
  ApiExperienceRepository(this._dio, this._auth, {this.onUnauthorized});

  final Dio _dio;
  final AuthRepository _auth;
  final Future<void> Function()? onUnauthorized;
  final Map<String, RouteExperience> _cachedRoutes = {};

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
  Future<List<RouteExperience>> routesForCity(String citySlug) async {
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
    return published;
  }

  @override
  Future<RouteExperience> featuredRoute(String citySlug) async {
    final routes = await routesForCity(citySlug);
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
    if (_cachedRoutes[slug] case final cached?) return cached;
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
    _cachedRoutes[slug] = route;
    return route;
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

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() action,
  ) async {
    try {
      return await action();
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await onUnauthorized?.call();
        throw const ExperienceFailure('登录已过期，请重新登录');
      }
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final envelope = responseData['error'];
        if (envelope is Map<String, dynamic>) {
          throw ExperienceFailure(envelope['message'] as String? ?? '请求失败');
        }
      }
      throw const ExperienceFailure('暂时无法连接见地服务，请检查网络后重试');
    }
  }
}
