import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class JiandiApp extends StatelessWidget {
  const JiandiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '见地',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
