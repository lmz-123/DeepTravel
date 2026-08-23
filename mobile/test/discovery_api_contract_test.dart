import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/experience/data/api_experience_repository.dart';

void main() {
  test('city discovery parses one optional center per scenic-area route',
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
                'routes': [
                  _routePayload,
                  {
                    ..._routePayload,
                    'id': 'route-b',
                    'slug': 'route-b',
                    'center': null,
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

    expect(catalog.routes, hasLength(2));
    expect(catalog.routes.first.centerLatitude, 22.5);
    expect(catalog.routes.first.centerLongitude, 114.0);
    expect(catalog.routes.last.centerLatitude, isNull);
    expect(catalog.routes.last.centerLongitude, isNull);
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
  'center': {'latitude': 22.5, 'longitude': 114.0},
  'stops': [],
};
