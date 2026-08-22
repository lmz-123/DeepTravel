import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../domain/auth_models.dart';

class AuthRepository {
  AuthRepository(this._dio);

  static const _tokenKey = 'user_auth_token';
  final Dio _dio;
  AuthSession? _session;

  AuthSession? get session => _session;
  String? get token => _session?.token;

  Future<AuthSession?> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      try {
        final response = await _dio.get(
          '/auth/me',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final user = AuthUser.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
        return _session = AuthSession(user: user, token: token);
      } on DioException {
        await preferences.remove(_tokenKey);
      }
    }
    if (AppConfig.testAuthEnabled) {
      return testLogin(AppConfig.defaultTestUser);
    }
    return null;
  }

  Future<AuthSession> register(String username, String password) =>
      _authenticate('/auth/register', {
        'username': username,
        'password': password,
      });

  Future<AuthSession> login(String username, String password) =>
      _authenticate('/auth/login', {
        'username': username,
        'password': password,
      });

  Future<AuthSession> testLogin(String alias) =>
      _authenticate('/auth/test-login', {'alias': alias});

  Future<void> logout() async {
    _session = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }

  Future<AuthSession> _authenticate(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(path, data: payload);
      final data = response.data['data'] as Map<String, dynamic>;
      final session = AuthSession(
        user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
        token: data['token'] as String,
      );
      _session = session;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_tokenKey, session.token);
      return session;
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map<String, dynamic> && body['error'] is Map) {
        final envelope = body['error'] as Map;
        throw AuthFailure(envelope['message'] as String? ?? '登录没有完成');
      }
      throw const AuthFailure('暂时无法连接见地服务');
    }
  }
}
