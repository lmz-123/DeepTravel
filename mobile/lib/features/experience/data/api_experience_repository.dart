import 'package:dio/dio.dart';

import '../domain/experience_repository.dart';
import '../domain/models.dart';

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
  RouteExperience? _cachedRoute;

  Future<void> _ensureGuest() async {
    if (_token != null) return;
    final response = await _request(() => _dio.post('/sessions/guest'));
    _token = (response.data['data'] as Map<String, dynamic>)['token'] as String;
  }

  Options get _authorized =>
      Options(headers: {'Authorization': 'Bearer $_token'});

  @override
  Future<RouteExperience> featuredRoute() async {
    final response = await _request(() => _dio.get('/cities/shanghai/routes'));
    final data = response.data['data'] as Map<String, dynamic>;
    final summaries = data['routes'] as List<dynamic>;
    if (summaries.isEmpty) throw const ExperienceFailure('这座城市还没有可用路线');
    final featured = summaries.cast<Map<String, dynamic>>().firstWhere(
          (item) => item['is_featured'] == true,
          orElse: () => summaries.first as Map<String, dynamic>,
        );
    return routeBySlug(featured['slug'] as String);
  }

  @override
  Future<RouteExperience> routeBySlug(String slug) async {
    if (_cachedRoute?.slug == slug) return _cachedRoute!;
    final response = await _request(() => _dio.get('/routes/$slug'));
    _cachedRoute = RouteExperience.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
    return _cachedRoute!;
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
  Future<JourneySession> arrive(String journeyId, {bool demo = true}) async {
    final response = await _request(
      () => _dio.post(
        '/journeys/$journeyId/arrivals',
        data: {'demo': demo},
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
