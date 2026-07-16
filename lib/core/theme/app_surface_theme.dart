import 'package:flutter/material.dart';

import 'app_card_theme.dart';

/// Sfondi condivisi (pagine, card, popup) — allineati a CreditCalc Store.
abstract final class AppSurfaceTheme {
  /// Sfondo pagine moduli autenticati.
  static const Color page = Colors.white;

  /// Sfondo pagine auth, bootstrap e gate.
  static const Color pageMuted = Color(0xFFE8E8E8);

  /// App bar / drawer secondari.
  static const Color appBar = Color(0xFFECEFF1);

  /// Card e pannelli contenuto.
  static const Color card = AppCardTheme.surface;

  /// Dialog, bottom sheet, popup menu.
  static const Color popup = Colors.white;

  static DialogThemeData dialogTheme({Color? backgroundColor}) {
    return DialogThemeData(
      backgroundColor: backgroundColor ?? popup,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  static BottomSheetThemeData get bottomSheetTheme {
    return const BottomSheetThemeData(
      backgroundColor: popup,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  static PopupMenuThemeData get popupMenuTheme {
    return PopupMenuThemeData(
      color: popup,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
