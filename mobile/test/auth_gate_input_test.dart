import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/auth/presentation/auth_gate.dart';
import 'package:jiandi/features/auth/presentation/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'production router shell provides an overlay and typing emits no request or framework error',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requestCount += 1;
      handler.resolve(
          Response(requestOptions: options, statusCode: 500, data: const {}));
    }));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('authenticated')),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(AuthRepository(dio)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => AuthGate(child: child ?? const SizedBox()),
      ),
    ));
    await tester.pumpAndSettle();

    final username = find.byKey(const ValueKey('auth-username'));
    await tester.tap(username);
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: 'liser',
      selection: TextSelection.collapsed(offset: 5),
    ));
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: 'lis',
      selection: TextSelection.collapsed(offset: 3),
    ));
    tester.testTextInput.updateEditingValue(const TextEditingValue(
      text: 'listt',
      selection: TextSelection.collapsed(offset: 5),
    ));
    await tester.pump();

    expect(find.text('listt'), findsOneWidget);
    expect(requestCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration submits the suffix-deletion result exactly',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    Map<String, dynamic>? submitted;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          submitted = Map<String, dynamic>.from(options.data as Map);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'data': {
                  'user': {
                    'id': 'user-listt',
                    'username': submitted!['username'],
                    'account_kind': 'registered',
                  },
                  'token': 'token-listt',
                },
              },
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(AuthRepository(dio)),
        ],
        child: const MaterialApp(
          home: AuthGate(child: Text('authenticated')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('第一次使用，注册账号'));
    await tester.pump();

    final username = find.byKey(const ValueKey('auth-username'));
    await tester.enterText(username, 'liser');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'lis',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'listt',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();
    expect(find.text('listt'), findsOneWidget);
    expect(submitted, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'password-123',
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();

    expect(submitted?['username'], 'listt');
    expect(submitted?['password'], 'password-123');
    expect(find.text('authenticated'), findsOneWidget);
  });

  testWidgets('switching account mode does not replace active field text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            AuthRepository(Dio(BaseOptions(baseUrl: 'https://api.test'))),
          ),
        ],
        child: const MaterialApp(
          home: AuthGate(child: SizedBox()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final username = find.byKey(const ValueKey('auth-username'));
    await tester.enterText(username, 'listt');
    await tester.tap(find.text('第一次使用，注册账号'));
    await tester.pump();

    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(field.controller.text, 'listt');
  });
}
