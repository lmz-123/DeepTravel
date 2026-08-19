import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF142B33);
  static const inkSoft = Color(0xFF29434A);
  static const terracotta = Color(0xFFC66A4A);
  static const moss = Color(0xFF66745B);
  static const paper = Color(0xFFF6F1E8);
  static const paperDeep = Color(0xFFECE4D7);
  static const gold = Color(0xFFD6B875);
  static const white = Color(0xFFFFFCF7);
}

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: AppColors.white,
      secondary: AppColors.terracotta,
      onSecondary: AppColors.white,
      tertiary: AppColors.moss,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      error: Color(0xFF9C3D35),
    ),
    scaffoldBackgroundColor: AppColors.paper,
    fontFamilyFallback: const ['PingFang SC', 'Noto Sans CJK SC', 'sans-serif'],
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 45,
        height: 1.08,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.8,
      ),
      displaySmall: TextStyle(
        fontSize: 34,
        height: 1.16,
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      titleLarge:
          TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w600),
      titleMedium:
          TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w600),
      bodyLarge:
          TextStyle(fontSize: 17, height: 1.72, fontWeight: FontWeight.w400),
      bodyMedium:
          TextStyle(fontSize: 15, height: 1.62, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.ink.withValues(alpha: 0.07)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: const TextStyle(color: AppColors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
