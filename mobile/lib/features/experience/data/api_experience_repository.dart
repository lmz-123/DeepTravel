import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  ApiExperienceRepository(this._dio);

  final Dio _dio;
  String? _token;
  final Map<String, RouteExperience> _cachedRoutes = {};

  Future<void> _ensureGuest() async {
    if (_token != null) return;
    final preferences = await SharedPreferences.getInstance();
    _token = preferences.getString('guest_token');
    if (_token != null) return;
    final response = await _request(() => _dio.post('/sessions/guest'));
    _token = (response.data['data'] as Map<String, dynamic>)['token'] as String;
    await preferences.setString('guest_token', _token!);
  }

  Options get _authorized =>
      Options(headers: {'Authorization': 'Bearer $_token'});

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
    return summaries
        .map((item) => RouteExperience.fromJson(item as Map<String, dynamic>))
        .toList();
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
    _cachedRoutes[slug] = route;
    return route;
  }

  @override
  Future<JourneySession> startOrResume(String routeId) async {
    await _ensureGuest();
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
    await _ensureGuest();
    await _request(() =>
        _dio.post('/journeys/$journeyId/active-tour', options: _authorized));
  }

  @override
  Future<void> stopActiveTour(String journeyId) async {
    await _ensureGuest();
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
    await _ensureGuest();
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
    await _ensureGuest();
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
    await _ensureGuest();
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
    await _ensureGuest();
    final response = await _request(
        () => _dio.get('/journeys/$journeyId/ledger', options: _authorized));
    return StoryLedger.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<ReconstructionResult> reconstruct(
      String journeyId, List<String> relationships) async {
    await _ensureGuest();
    final response = await _request(() => _dio.post(
        '/journeys/$journeyId/reconstruction',
        data: {'relationships': relationships},
        options: _authorized));
    return ReconstructionResult.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<FragmentRecap> fragmentRecap(String journeyId) async {
    await _ensureGuest();
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
