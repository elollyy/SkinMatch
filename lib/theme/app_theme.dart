import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = _buildTheme(Brightness.light);
  static ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.milkDark : AppColors.milk;
    final surfaceCard = isDark ? AppColors.neutral50Dark : Colors.white;
    final border = isDark ? AppColors.neutral300Dark : AppColors.neutral100;
    final primary = isDark ? AppColors.rose400Dark : AppColors.rose400;
    final secondary = isDark ? AppColors.blue400Dark : AppColors.blue400;
    final onSurface = isDark ? AppColors.neutral900Dark : AppColors.neutral900;
    final muted = isDark ? AppColors.neutral500Dark : AppColors.neutral500;
    final body = isDark ? AppColors.neutral700Dark : AppColors.neutral700;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: onSurface,
        error: const Color(0xFFC85B56),
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
    );

    return base.copyWith(
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          height: 1,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          color: onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 30,
          height: 1.08,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
          color: onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          height: 1.15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: onSurface),
        bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: body),
        bodySmall: TextStyle(fontSize: 13, height: 1.5, color: muted),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: muted,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: muted,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.24),
        selectionHandleColor: primary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withValues(alpha: 0.92),
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.neutral100Dark
            : AppColors.neutral900,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      cardColor: surfaceCard,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          disabledBackgroundColor: border,
          disabledForegroundColor: muted,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.neutral100Dark.withValues(alpha: 0.7)
            : AppColors.neutral50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC85B56), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC85B56), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(fontSize: 14, color: muted),
        hintStyle: TextStyle(fontSize: 15, color: muted.withValues(alpha: 0.7)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: isDark
            ? AppColors.neutral100Dark
            : AppColors.neutral100,
      ),
    );
  }
}
