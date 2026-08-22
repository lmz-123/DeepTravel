import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiandi/features/auth/data/auth_repository.dart';
import 'package:jiandi/features/auth/presentation/auth_gate.dart';
import 'package:jiandi/features/auth/presentation/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('username input does not restore deleted IME suggestions',
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

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('auth-username')),
    );
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.smartDashesType, SmartDashesType.disabled);
    expect(field.smartQuotesType, SmartQuotesType.disabled);
    expect(field.textCapitalization, TextCapitalization.none);

    await tester.enterText(
      find.byKey(const ValueKey('auth-username')),
      '旅行者-old',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-username')),
      '旅行者-new',
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      '旅行者-new',
    );
  });
}
