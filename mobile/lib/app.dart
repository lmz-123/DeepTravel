import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging/runtime_log_reporter.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/experience/data/api_experience_repository.dart';
import 'features/experience/presentation/experience_providers.dart';

class JiandiApp extends ConsumerStatefulWidget {
  const JiandiApp({super.key});

  @override
  ConsumerState<JiandiApp> createState() => _JiandiAppState();
}

class _JiandiAppState extends ConsumerState<JiandiApp> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    final reporter = ref.read(runtimeLogReporterProvider);
    if (reporter != null) {
      _lifecycle = AppLifecycleListener(
        onResume: () {
          unawaited(reporter.info('lifecycle', 'application_resumed'));
          unawaited(reporter.flush());
        },
        onPause: () =>
            unawaited(reporter.info('lifecycle', 'application_paused')),
      );
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usesRemoteApi =
        ref.watch(experienceRepositoryProvider) is ApiExperienceRepository;
    return MaterialApp.router(
      title: '见地',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      builder: (context, child) =>
          AppConfig.mode == AppMode.demo || !usesRemoteApi
              ? child ?? const SizedBox()
              : AuthGate(child: child ?? const SizedBox()),
    );
  }
}
