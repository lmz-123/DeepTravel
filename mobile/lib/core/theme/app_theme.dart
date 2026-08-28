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
  static const line = Color(0x1A142B33);
  static const textMuted = Color(0xFF687571);
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
        fontFamily: 'Songti SC',
        fontFamilyFallback: ['STSong', 'Noto Serif CJK SC', 'serif'],
        fontSize: 43,
        height: 1.12,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.2,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Songti SC',
        fontFamilyFallback: ['STSong', 'Noto Serif CJK SC', 'serif'],
        fontSize: 32,
        height: 1.18,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.8,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Songti SC',
        fontFamilyFallback: ['STSong', 'Noto Serif CJK SC', 'serif'],
        fontSize: 25,
        height: 1.28,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Songti SC',
        fontFamilyFallback: ['STSong', 'Noto Serif CJK SC', 'serif'],
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Songti SC',
        fontFamilyFallback: ['STSong', 'Noto Serif CJK SC', 'serif'],
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge:
          TextStyle(fontSize: 16, height: 1.72, fontWeight: FontWeight.w400),
      bodyMedium:
          TextStyle(fontSize: 14, height: 1.62, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      labelMedium: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.7),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white.withValues(alpha: .72),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.terracotta, width: 1.4),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.paperDeep,
      selectedColor: AppColors.moss,
      disabledColor: AppColors.paperDeep,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.ink),
      secondaryLabelStyle: const TextStyle(color: AppColors.white),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
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
