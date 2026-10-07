import 'package:flutter/material.dart';

/// Vibrant, gamified palette shared by light and dark themes.
class AppColors {
  AppColors._();

  static const violet = Color(0xFF7C4DFF);
  static const teal = Color(0xFF00E5C3);
  static const sunset = Color(0xFFFF6D3A);
  static const gold = Color(0xFFFFC233);
  static const pink = Color(0xFFFF4FA3);
  static const sky = Color(0xFF3DA9FF);
  static const xp = Color(0xFF8BE04E);

  static const gradientPrimary = LinearGradient(
    colors: [violet, Color(0xFF4D7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientReward = LinearGradient(
    colors: [gold, sunset],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientGo = LinearGradient(
    colors: [teal, Color(0xFF00B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: b,
      primary: AppColors.violet,
      secondary: AppColors.teal,
      tertiary: AppColors.sunset,
      surface: dark ? const Color(0xFF12111C) : const Color(0xFFF7F5FF),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF1E1C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        indicatorColor: AppColors.violet.withValues(alpha: 0.18),
        backgroundColor: dark ? const Color(0xFF181726) : Colors.white,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: scheme.onSurface),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF242236) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}
