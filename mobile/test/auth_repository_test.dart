import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('register persists token and restore resolves the same account',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/auth/register') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'data': {
                    'user': {
                      'id': 'user-a',
                      'username': 'traveler-a',
                      'account_kind': 'registered',
                    },
                    'token': 'safe-token-a',
                  },
                },
              ),
            );
            return;
          }
          expect(options.path, '/auth/me');
          expect(options.headers['Authorization'], 'Bearer safe-token-a');
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'data': {
                  'id': 'user-a',
                  'username': 'traveler-a',
                  'account_kind': 'registered',
                },
              },
            ),
          );
        },
      ),
    );

    final first = AuthRepository(dio);
    final registered = await first.register('traveler-a', 'field-test-123');
    expect(registered.user.id, 'user-a');

    final restored = await AuthRepository(dio).restore();
    expect(restored?.user.id, 'user-a');
    expect(restored?.token, 'safe-token-a');
  });

  test('logout removes the stored bearer token', () async {
    SharedPreferences.setMockInitialValues({'user_auth_token': 'expired'});
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 401),
            type: DioExceptionType.badResponse,
          ),
        ),
      ),
    );

    expect(await AuthRepository(dio).restore(), isNull);
    expect(
      (await SharedPreferences.getInstance()).getString('user_auth_token'),
      isNull,
    );
  });
}
