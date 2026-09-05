import 'package:flutter/material.dart';

const kPrimary = Color(0xFF1D4ED8);
const kPrimaryLight = Color(0xFFEFF6FF);
const kPrimaryBorder = Color(0xFFBFDBFE);
const kPromo = Color(0xFFFEF3C7);
const kPromoText = Color(0xFF92400E);
const kGreen = Color(0xFF059669);
const kOrange = Color(0xFFD97706);
const kBg = Color(0xFFF7F8FA);
const kCard = Color(0xFFFFFFFF);
const kBorder = Color(0xFFE5E7EB);
const kTextPrimary = Color(0xFF111827);
const kTextSecondary = Color(0xFF6B7280);
const kTextHint = Color(0xFF9CA3AF);


extension ThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get appBg => isDark ? const Color(0xFF121212) : kBg;
  Color get appCard => isDark ? const Color(0xFF1E1E1E) : kCard;
  Color get appBorder => isDark ? const Color(0xFF333333) : kBorder;
  Color get appTextPrimary => isDark ? Colors.white : kTextPrimary;
  Color get appTextSecondary => isDark ? Colors.white70 : kTextSecondary;
  Color get appTextHint => isDark ? Colors.white38 : kTextHint;
}

ThemeData appThemeLight() {
  return ThemeData(
    brightness: Brightness.light,
    textTheme: _buildBoldTextTheme(ThemeData.light().textTheme),
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.light,
      seedColor: kPrimary,
      primary: kPrimary,
      surface: kCard,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kCard,
      foregroundColor: kTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.bold),
    ),
  );
}

ThemeData appThemeDark() {
  return ThemeData(
    brightness: Brightness.dark,
    textTheme: _buildBoldTextTheme(ThemeData.dark().textTheme),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: kPrimary,
      primary: kPrimary,
      surface: const Color(0xFF1E1E1E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
    ),
  );
}


TextTheme _buildBoldTextTheme(TextTheme base) {
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.bold),
    displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.bold),
    displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.bold),
    headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
    bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
    bodySmall: base.bodySmall?.copyWith(fontWeight: FontWeight.bold),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.bold),
    labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.bold),
    labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.bold),
  );
}
