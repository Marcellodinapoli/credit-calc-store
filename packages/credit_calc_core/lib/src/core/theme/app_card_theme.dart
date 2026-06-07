import 'package:flutter/material.dart';

/// Stile card condiviso (come le card in "I miei progressi").
abstract final class AppCardTheme {
  /// Grigio chiaro (ex. contenitore in I miei progressi / card Home).
  static const Color surface = Color(0xFFF7F7FA);
  static const double elevation = 2;
  static const double radius = 12;

  /// Spazio tra card in liste e colonne (come in I miei progressi).
  static const EdgeInsets margin = EdgeInsets.only(bottom: 12);

  static RoundedRectangleBorder get shape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      );

  static CardThemeData get cardTheme => CardThemeData(
        color: surface,
        elevation: elevation,
        shape: shape,
        margin: margin,
      );
}
