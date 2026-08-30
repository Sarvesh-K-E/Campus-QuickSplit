import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Vibrant Neo-Brutalist Palette
  static const Color neoYellow = Color(0xFFFFDE59);
  static const Color neoPink = Color(0xFFFF90E8);
  static const Color neoBlue = Color(0xFF00C2FF);
  static const Color neoRed = Color(0xFFFF3366);
  static const Color neoGreen = Color(0xFF00E599);
  static const Color neoOrange = Color(0xFFFF6D00);
  static const Color neoPurple = Color(0xFFC77DFF);
  
  // Legacy Accent Colors (kept for compatibility if needed, but transitioning to vibrant)
  static const Color accentYellow = neoYellow;
  static const Color accentPink = neoPink;
  static const Color accentGreen = neoGreen;
  
  // Light Mode Colors
  static const Color lightBackground = Color(0xFFFFFDF0); // Cream off-white
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Colors.black;
  static const Color lightTextPrimary = Colors.black;
  static const Color lightTextSecondary = Color(0xFF4A4A4A);

  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkBorder = Colors.white;
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFB0B0B0);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: accentGreen,
      scaffoldBackgroundColor: lightBackground,
      textTheme: GoogleFonts.spaceGroteskTextTheme().copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(color: lightTextPrimary, fontWeight: FontWeight.w900, letterSpacing: -1),
        bodyLarge: GoogleFonts.spaceGrotesk(color: lightTextPrimary, fontWeight: FontWeight.w600),
        bodyMedium: GoogleFonts.spaceGrotesk(color: lightTextSecondary, fontWeight: FontWeight.w500),
        titleMedium: GoogleFonts.spaceGrotesk(color: lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(color: lightTextPrimary, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Space Grotesk'),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightBackground,
        indicatorColor: Colors.transparent,
        labelTextStyle: MaterialStateProperty.all(const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: lightTextPrimary)),
        elevation: 0,
        shadowColor: Colors.transparent,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide.none,
        ),
        overlayColor: MaterialStateProperty.all(Colors.transparent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentYellow,
          foregroundColor: lightTextPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
            side: const BorderSide(color: lightBorder, width: 3),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Space Grotesk'),
          elevation: 0,
        ).copyWith(
          elevation: MaterialStateProperty.resolveWith<double>((Set<MaterialState> states) {
            if (states.contains(MaterialState.pressed)) return 0;
            return 4; // Native Flutter elevated buttons don't support hard unblurred offset shadows easily via elevation, we'll override shadowColor if needed, but elevation 0 and custom container is better for brutalism.
          }),
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0, // We will manually add hard shadows in containers or use Card decoration where possible
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: lightBorder, width: 3),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentPink,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: lightBorder, width: 3),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: lightBorder, width: 3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: lightBorder, width: 3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: lightBorder, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.red, width: 3),
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: accentGreen,
        secondary: accentYellow,
        surface: lightSurface,
        background: lightBackground,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: accentGreen,
      scaffoldBackgroundColor: darkBackground,
      textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(color: darkTextPrimary, fontWeight: FontWeight.w900, letterSpacing: -1),
        bodyLarge: GoogleFonts.spaceGrotesk(color: darkTextPrimary, fontWeight: FontWeight.w600),
        bodyMedium: GoogleFonts.spaceGrotesk(color: darkTextSecondary, fontWeight: FontWeight.w500),
        titleMedium: GoogleFonts.spaceGrotesk(color: darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(color: darkTextPrimary, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Space Grotesk'),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBackground,
        indicatorColor: Colors.transparent,
        labelTextStyle: MaterialStateProperty.all(const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: darkTextPrimary)),
        elevation: 0,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide.none,
        ),
        overlayColor: MaterialStateProperty.all(Colors.transparent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentYellow,
          foregroundColor: Colors.black, // Dark text on bright button
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0),
            side: const BorderSide(color: darkBorder, width: 3),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'Space Grotesk'),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
          side: const BorderSide(color: darkBorder, width: 3),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentPink,
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: darkBorder, width: 3),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: darkBorder, width: 3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: darkBorder, width: 3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: darkBorder, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.red, width: 3),
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: accentGreen,
        secondary: accentYellow,
        surface: darkSurface,
        background: darkBackground,
      ),
    );
  }
}
