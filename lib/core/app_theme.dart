import 'package:flutter/material.dart';

class AppColors {
  static const purple = Color(0xFF140B3B);
  static const purple700 = Color(0xFF3B2B6C);
  static const blue = Color(0xFF033065);
  static const yellow = Color(0xFFFAB206);
  static const red = Color(0xFFE5391C);
  static const green = Color(0xFF5B8744);
  static const background = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF140B3B);
  static const muted = Color(0xFF6B7280);
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const border = Color(0xFFE5E7EB);
}

class AppShadows {
  static const sm = [
    BoxShadow(color: Color(0x10140B3B), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const md = [
    BoxShadow(color: Color(0x1A140B3B), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const lg = [
    BoxShadow(color: Color(0x24140B3B), blurRadius: 28, offset: Offset(0, 12)),
  ];
}

ThemeData buildVenexusTheme() {
  final squareBorder = RoundedRectangleBorder(borderRadius: BorderRadius.zero);

  return ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.blue,
      secondary: AppColors.yellow,
      error: AppColors.red,
      surface: AppColors.surface,
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.text, fontFamily: 'Inter', height: 1.25),
      bodyLarge: TextStyle(color: AppColors.text, fontFamily: 'Inter', height: 1.25),
      titleLarge: TextStyle(color: AppColors.purple, fontFamily: 'Inter', fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: AppColors.purple, fontFamily: 'Inter', fontWeight: FontWeight.w800),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.purple,
      titleTextStyle: TextStyle(
        color: AppColors.purple,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        fontFamily: 'Inter',
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: TextStyle(color: AppColors.gray600, fontWeight: FontWeight.w700),
      floatingLabelStyle: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.gray300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.gray300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.blue, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.red, width: 1.4)),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: AppColors.gray200),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: squareBorder,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
          fontFamily: 'Inter',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: AppColors.gray300),
        shape: squareBorder,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
          fontFamily: 'Inter',
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue,
        shape: squareBorder,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Inter'),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.blue,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.purple,
      contentTextStyle: TextStyle(color: Colors.white, fontFamily: 'Inter'),
    ),
  );
}
