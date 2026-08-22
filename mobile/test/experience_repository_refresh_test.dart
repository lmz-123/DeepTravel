import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/experience/data/api_experience_repository.dart';

void main() {
  test(
      'route detail refetches published voice profiles instead of staying stale',
      () async {
    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/routes/dameisha-remade-coast');
          requestCount += 1;
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'id': 'route-dameisha',
                  'slug': 'dameisha-remade-coast',
                  'title': '大梅沙版本 $requestCount',
                  'subtitle': '测试',
                  'description': '测试路线',
                  'duration_minutes': 75,
                  'distance_km': 1.8,
                  'difficulty': '轻松',
                  'theme': '海岸',
                  'hero_image': 'https://example.test/cover.png',
                  'content_status': 'published',
                  'is_featured': true,
                  'stop_count': 5,
                  'stops': const [],
                },
              },
            ),
          );
        },
      ),
    );
    final repository = ApiExperienceRepository(dio, AuthRepository(dio));

    final first = await repository.routeBySlug('dameisha-remade-coast');
    final refreshed = await repository.routeBySlug('dameisha-remade-coast');

    expect(requestCount, 2);
    expect(first.title, '大梅沙版本 1');
    expect(refreshed.title, '大梅沙版本 2');
  });
}
