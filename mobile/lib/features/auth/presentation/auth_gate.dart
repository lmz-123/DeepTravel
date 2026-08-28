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
      backgroundColor: AppColors.ink,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(.72, -.82),
            radius: 1.15,
            colors: [Color(0x554F5D45), AppColors.ink],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BrandMark(light: true),
                      ),
                      const SizedBox(height: 72),
                      Text(
                        'KEEP WHAT YOU NOTICE',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.gold,
                                  letterSpacing: 1.4,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _register ? '建立一份只属于你的\n旅行档案。' : '登录以后，\n让走过的城市留下来。',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(color: AppColors.white),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '同步足迹、收藏与离线手册。进度和现场照片只属于这个账号。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.white.withValues(alpha: .62),
                            ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _register ? '注册账号' : '账号登录',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              key: const ValueKey('auth-username'),
                              decoration:
                                  const InputDecoration(labelText: '用户名'),
                              textInputAction: TextInputAction.next,
                              onSaved: (value) => _username = value ?? '',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('auth-password'),
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: '密码（至少 8 位）',
                              ),
                              onSaved: (value) => _password = value ?? '',
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                error,
                                style: const TextStyle(
                                  color: AppColors.terracotta,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            FilledButton(
                              key: const ValueKey('auth-submit'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.terracotta,
                              ),
                              onPressed: auth.isLoading ? null : _submit,
                              child: Text(_register ? '注册并开始' : '登录并继续'),
                            ),
                            TextButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () =>
                                      setState(() => _register = !_register),
                              child: Text(
                                _register ? '已有账号，直接登录' : '第一次使用，注册账号',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '继续即表示你同意用户协议与隐私政策。定位仅在行走导览中用于判断是否靠近故事点。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: .46),
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
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
