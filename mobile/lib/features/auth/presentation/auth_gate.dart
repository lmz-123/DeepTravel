import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import 'auth_provider.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authControllerProvider).when(
          loading: () => const ColoredBox(
            color: AppColors.paper,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _AuthNavigator(initialError: error.toString()),
          data: (session) => session == null ? const _AuthNavigator() : child,
        );
  }
}

class _AuthNavigator extends StatelessWidget {
  const _AuthNavigator({this.initialError});

  final String? initialError;

  @override
  Widget build(BuildContext context) => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/auth'),
          builder: (_) => _AuthPage(initialError: initialError),
        ),
      );
}

class _AuthPage extends ConsumerStatefulWidget {
  const _AuthPage({this.initialError});
  final String? initialError;

  @override
  ConsumerState<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<_AuthPage> {
  final _formKey = GlobalKey<FormState>();
  var _username = '';
  var _password = '';
  var _register = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final error = auth.hasError ? auth.error.toString() : widget.initialError;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                        alignment: Alignment.centerLeft, child: BrandMark()),
                    const SizedBox(height: 48),
                    Text(
                      _register ? '建立你的旅行档案' : '继续上一次行走',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '进度和现场照片只属于这个账号。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      key: const ValueKey('auth-username'),
                      decoration: const InputDecoration(labelText: '用户名'),
                      textInputAction: TextInputAction.next,
                      onSaved: (value) => _username = value ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('auth-password'),
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: '密码（至少 8 位）'),
                      onSaved: (value) => _password = value ?? '',
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Text(error,
                          style: const TextStyle(color: AppColors.terracotta)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('auth-submit'),
                      onPressed: auth.isLoading ? null : _submit,
                      child: Text(_register ? '注册并开始' : '登录'),
                    ),
                    TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => setState(() => _register = !_register),
                      child: Text(_register ? '已有账号，直接登录' : '第一次使用，注册账号'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    final form = _formKey.currentState;
    if (form == null) return;
    form.save();
    final controller = ref.read(authControllerProvider.notifier);
    if (_register) {
      controller.register(_username, _password);
    } else {
      controller.login(_username, _password);
    }
  }
}
