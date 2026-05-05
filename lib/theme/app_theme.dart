// THEME LOCK: light — source: domain signal (student consumer app)
// Scaffold.backgroundColor = AppTheme.backgroundLight — ALL screens

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary brand colors
  static const Color primary = Color.fromARGB(255,114,46,133);
  static const Color primaryLight = Color.fromARGB(255, 124, 62, 231);
  static const Color primaryContainer = Color(0xFFEDE9FE);

  // Accent colors
  static const Color teal = Color(0xFF0D9488);
  static const Color tealLight = Color(0xFF14B8A6);
  static const Color tealContainer = Color(0xFFCCFBF1);

  static const Color orange = Color(0xFFEA580C);
  static const Color orangeContainer = Color(0xFFFFEDD5);

  // Semantic colors
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color critical = Color(0xFFDC2626);

  // Light surfaces
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF5F5F7);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color dividerLight = Color(0xFFE5E7EB);

  // Dark surfaces
  static const Color surfaceDark = Color(0xFF1E1B2E);
  static const Color backgroundDark = Color(0xFF120F1E);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: Color(0xFF3B0764),
      secondary: teal,
      onSecondary: Colors.white,
      secondaryContainer: tealContainer,
      onSecondaryContainer: Color(0xFF042F2E),
      tertiary: orange,
      onTertiary: Colors.white,
      surface: surfaceLight,
      onSurface: Color(0xFF1A1A2E),
      surfaceContainerHighest: Color(0xFFF3F4F6),
      onSurfaceVariant: Color(0xFF6B7280),
      error: error,
      onError: Colors.white,
      outline: Color(0xFFD1D5DB),
      outlineVariant: Color(0xFFE5E7EB),
    ),
    scaffoldBackgroundColor: backgroundLight,
    textTheme: GoogleFonts.dmSansTextTheme(
      TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFF374151),
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFF374151),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF6B7280),
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      labelStyle: TextStyle(color: Color(0xFF6B7280)),
      floatingLabelStyle: TextStyle(color: primary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Color(0xFFF3F4F6),
      selectedColor: primary,
      labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primary,
      unselectedItemColor: Color(0xFF9CA3AF),
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
    dividerTheme: DividerThemeData(
      color: Color(0xFFE5E7EB),
      thickness: 1,
      space: 0,
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: primaryLight,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF3B0764),
      onPrimaryContainer: Color(0xFFEDE9FE),
      secondary: tealLight,
      onSecondary: Colors.white,
      surface: surfaceDark,
      onSurface: Color(0xFFE6E6E6),
      error: Color(0xFFCF6679),
      onError: Colors.white,
      outline: Color(0xFF4B5563),
      outlineVariant: Color(0xFF374151),
    ),
    scaffoldBackgroundColor: backgroundDark,
    textTheme: GoogleFonts.dmSansTextTheme(
      TextTheme(
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE6E6E6),
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE6E6E6),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE6E6E6),
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFFD1D5DB),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF9CA3AF),
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}
