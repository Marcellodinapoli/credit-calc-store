import 'package:flutter/material.dart';

/// Stili per azioni secondarie (annulla, esci) leggibili su sfondo chiaro e scuro.
abstract final class AppActionStyles {
  static const Color cancelForeground = Color(0xFFB71C1C);
  static const Color cancelBorder = Color(0xFFC62828);

  static ButtonStyle get cancelOutlined => OutlinedButton.styleFrom(
        foregroundColor: cancelForeground,
        backgroundColor: Colors.white,
        disabledForegroundColor: Color(0xFF757575),
        disabledBackgroundColor: Color(0xFFEEEEEE),
        side: const BorderSide(color: cancelBorder, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        surfaceTintColor: Colors.white,
        iconColor: cancelForeground,
      );

  static ButtonStyle get cancelText => TextButton.styleFrom(
        foregroundColor: cancelForeground,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      );

  static ButtonStyle get dialogAction => TextButton.styleFrom(
        foregroundColor: const Color(0xFF0A66C2),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      );
}
