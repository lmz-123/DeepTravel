import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/experience/data/api_experience_repository.dart';

void main() {
  test('city discovery parses scenic points and old empty-tag payloads',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'routes': [_routePayload],
                'scenic_spots': const [
                  {
                    'id': 'spot-a',
                    'title': '旧城墙',
                    'latitude': 22.5,
                    'longitude': 114.0,
                    'experience_tags': ['城市历史', '未来新增标签'],
                    'route_id': 'route-a',
                  },
                  {
                    'id': 'spot-b',
                    'title': '海边',
                    'latitude': 22.6,
                    'longitude': 114.1,
                    'route_id': 'route-a',
                  },
                ],
              },
            },
          ),
        ),
      ),
    );
    final repository = ApiExperienceRepository(dio, AuthRepository(dio));

    final catalog = await repository.discoveryForCity('shenzhen');

    expect(catalog.routes.single.id, 'route-a');
    expect(catalog.scenicSpots.first.experienceTags, ['城市历史', '未来新增标签']);
    expect(catalog.scenicSpots.last.experienceTags, isEmpty);
  });
}

const _routePayload = {
  'id': 'route-a',
  'slug': 'route-a',
  'title': '测试路线',
  'subtitle': '测试',
  'description': '测试路线',
  'duration_minutes': 30,
  'distance_km': 1.2,
  'difficulty': '轻松',
  'theme': '城市历史',
  'hero_image': '',
  'content_status': 'published',
  'is_featured': true,
  'stop_count': 2,
  'stops': [],
};
