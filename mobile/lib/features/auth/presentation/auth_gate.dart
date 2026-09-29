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
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          Positioned(
            right: -82,
            top: -48,
            child: Transform.rotate(
              angle: .16,
              child: Container(
                width: 235,
                height: 235,
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: .72),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink.withValues(alpha: .08)),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(23, 18, 23, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const BrandMark(),
                            const Spacer(),
                            Text('PRIVATE FILE / 见地档案', style: TextStyle(fontSize: 9, letterSpacing: .9, color: AppColors.textMuted)),
                          ],
                        ),
                        const SizedBox(height: 54),
                        Text('KEEP WHAT YOU NOTICE', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.terracotta, letterSpacing: 1.4)),
                        const SizedBox(height: 11),
                        Text(_register ? '建立一份只属于你的\n旅行档案。' : '登录以后，\n让走过的城市留下来。', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.ink, fontSize: 35)),
                        const SizedBox(height: 11),
                        Text('同步足迹、收藏与离线手册。进度和现场照片只属于这个账号。', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 19, 18, 13),
                          decoration: const BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(28), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(_register ? '注册账号' : '账号登录', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.paper)),
                              const SizedBox(height: 17),
                              Theme(
                                data: Theme.of(context).copyWith(inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(filled: true, fillColor: AppColors.paper.withValues(alpha: .1), labelStyle: const TextStyle(color: Color(0xffc5c7b9)), errorStyle: const TextStyle(color: Color(0xffffb09d), fontSize: 11), enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0x665f695c))), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.lime, width: 1.5)))),
                                child: Column(children: [
                                  TextFormField(
                                    key: const ValueKey('auth-username'),
                                    style: const TextStyle(color: AppColors.paper),
                                    decoration: const InputDecoration(labelText: '用户名'),
                                    textInputAction: TextInputAction.next,
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? '请输入用户名'
                                            : null,
                                    onSaved: (value) => _username = value?.trim() ?? '',
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    key: const ValueKey('auth-password'),
                                    style: const TextStyle(color: AppColors.paper),
                                    obscureText: true,
                                    decoration: const InputDecoration(labelText: '密码'),
                                    validator: (value) =>
                                        value == null || value.isEmpty
                                            ? '请输入密码'
                                            : null,
                                    onSaved: (value) => _password = value ?? '',
                                    onFieldSubmitted: (_) => _submit(),
                                  ),
                                ]),
                              ),
                              if (error != null) ...[const SizedBox(height: 12), Text(error, style: const TextStyle(color: Color(0xffffb09d), fontSize: 12))],
                              const SizedBox(height: 15),
                              FilledButton(key: const ValueKey('auth-submit'), style: FilledButton.styleFrom(backgroundColor: AppColors.terracotta, foregroundColor: AppColors.white, minimumSize: const Size.fromHeight(52), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(18), bottomLeft: Radius.circular(3), bottomRight: Radius.circular(3)))), onPressed: auth.isLoading ? null : _submit, child: Text(_register ? '注册并开始' : '登录并继续')),
                              TextButton(onPressed: auth.isLoading ? null : () => setState(() => _register = !_register), child: Text(_register ? '已有账号，直接登录' : '第一次使用，注册账号', style: const TextStyle(color: AppColors.lime, fontSize: 12))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('定位只在你主动开启随行后，用于判断是否靠近故事点。打开页面不会请求定位，也不会自动播放。', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.7)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    form.save();
    final controller = ref.read(authControllerProvider.notifier);
    if (_register) {
      controller.register(_username, _password);
    } else {
      controller.login(_username, _password);
    }
  }
}
