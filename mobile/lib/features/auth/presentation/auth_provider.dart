import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

final authDioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      contentType: Headers.jsonContentType,
    )));

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(authDioProvider)),
);

class AuthController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() => _repository.restore();

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.login(username, password));
  }

  Future<void> register(String username, String password) async {
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => _repository.register(username, password));
  }

  Future<void> switchTestUser(String alias) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.testLogin(alias));
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncData(null);
  }

  Future<void> expire() => logout();
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);
