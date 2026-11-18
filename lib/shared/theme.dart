import 'package:flutter/material.dart';

abstract final class AppColors {
  static const firefly = Color(0xFF032C30);
  static const prussianBlue = Color(0xFF032B52);
  static const mint = Color(0xFF8FD1B1);
  static const mintLight = Color(0xFFDDF1E6);
  static const gold = Color(0xFFCBAF2B);
  static const lime = Color(0xFFC3D96E);
  static const wine = Color(0xFF8B2E3C);
  static const background = Color(0xFFF4FAF6);
  static const muted = Color(0xFF5F7C7A);
  static const border = Color(0xFFD2E5DA);
  static const success = Color(0xFF2E7D4F);
  static const paleGold = Color(0xFFF6EDBF);
  static const paleRose = Color(0xFFF4DDE0);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.firefly,
    secondary: AppColors.mint,
    surface: Colors.white,
    error: AppColors.wine,
    onPrimary: Colors.white,
    onSecondary: AppColors.firefly,
    onSurface: AppColors.firefly,
    onError: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w700, color: AppColors.firefly),
      headlineMedium: TextStyle(fontSize: 22, height: 1.3, fontWeight: FontWeight.w700, color: AppColors.firefly),
      titleLarge: TextStyle(fontSize: 16, height: 1.3, fontWeight: FontWeight.w600, color: AppColors.firefly),
      titleMedium: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: AppColors.firefly),
      bodyLarge: TextStyle(fontSize: 14, height: 1.4, color: AppColors.firefly),
      bodyMedium: TextStyle(fontSize: 13, height: 1.4, color: AppColors.firefly),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.firefly,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 24, height: 1.3, fontWeight: FontWeight.w700, color: AppColors.firefly),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.firefly, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.wine)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.firefly,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
