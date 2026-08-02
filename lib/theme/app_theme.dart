import 'package:flutter/material.dart';

class AppColors {
  static const teal = Color(0xFF2A9D8F);
  static const coral = Color(0xFFF4A261);
  static const cream = Color(0xFFF7F3ED);
}

class AppRadius {
  static const card = 20.0;
}

class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

class AppTheme {
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F7A6E), AppColors.teal],
  );

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        brightness: Brightness.light,
        primary: AppColors.teal,
        secondary: AppColors.coral,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        brightness: Brightness.dark,
        primary: AppColors.teal,
        secondary: AppColors.coral,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
    );
  }
}
