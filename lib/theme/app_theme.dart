import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.mistBlue,
      brightness: Brightness.light,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamilyFallback: const ['PingFang SC', 'Noto Sans CJK SC'],
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 28,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: AppColors.secondaryInk,
          fontSize: 14,
          height: 1.5,
        ),
        labelMedium: TextStyle(
          color: AppColors.secondaryInk,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
