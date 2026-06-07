import 'package:flutter/material.dart';

import 'theme/app_card_theme.dart';

const Color kJobBrand = Color(0xFF00C2A8);
const Color kJobBrandLight = Color(0xFFE3F7F4);
const Color kJobBrandDark = Color(0xFF008E7E);
const Color kJobTextPrimary = Colors.black87;
const Color kJobTextOnBrand = Colors.white;

ThemeData buildJobTheme() {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kJobBrand,
      primary: kJobBrand,
      secondary: kJobBrandDark,
      surface: Colors.white,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kJobBrand,
      foregroundColor: kJobTextOnBrand,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: kJobTextOnBrand,
      ),
      iconTheme: IconThemeData(color: kJobTextOnBrand),
    ),
    cardTheme: AppCardTheme.cardTheme,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kJobBrand,
        foregroundColor: kJobTextOnBrand,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kJobBrand,
        side: const BorderSide(color: kJobBrand, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kJobBrand,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.black,
      unselectedLabelColor: Colors.black54,
      indicatorColor: kJobBrandDark,
      labelStyle: TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      dividerColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kJobBrand,
        foregroundColor: kJobTextOnBrand,
        minimumSize: const Size(0, 48),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: kJobBrandLight,
      selectedColor: kJobBrand,
      labelStyle: const TextStyle(color: kJobTextPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE8EAED),
      thickness: 1,
      space: 24,
    ),
  );
}
