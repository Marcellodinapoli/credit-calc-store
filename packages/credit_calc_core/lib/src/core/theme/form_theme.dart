import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_card_theme.dart';
import 'project_colors.dart';

/// ThemeData dedicato alla sezione FORM (usa ProjectColors)
ThemeData buildFormTheme() {
  final base = ThemeData.light(useMaterial3: true);

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: Colors.black87,
    displayColor: Colors.black87,
  );

  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: ProjectColors.form,       // 🔹 arancio tenue (#FFA726)
      primary: ProjectColors.form,
      secondary: const Color(0xFFF57C00), // 🔹 variante scura (manuale)
      surface: Colors.white,
      brightness: Brightness.light,
    ),
    textTheme: textTheme,

    // AppBar arancio con testo bianco
    appBarTheme: const AppBarTheme(
      backgroundColor: ProjectColors.form,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    // Card morbide
    cardTheme: AppCardTheme.cardTheme,

    // Bottoni con brand
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ProjectColors.form,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ProjectColors.form,
        side: const BorderSide(color: ProjectColors.form, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ProjectColors.form,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    // ✅ TabBarThemeData al posto di TabBarTheme
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.black,
      unselectedLabelColor: Colors.black54,
      indicatorColor: Color(0xFFF57C00), // 🔹 variante scura arancio
      labelStyle: TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      dividerColor: Colors.transparent,
    ),

    // Chip/pill
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: const Color(0xFFFFF3E0), // 🔹 pill arancio chiaro
      selectedColor: ProjectColors.form,
      labelStyle: const TextStyle(color: Colors.black87),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // Divider leggero
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE8EAED),
      thickness: 1,
      space: 24,
    ),
  );
}
