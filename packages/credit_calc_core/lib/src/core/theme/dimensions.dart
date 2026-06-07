import 'package:flutter/material.dart';

/// Costanti per dimensioni, padding e responsive layout
class Dimensions {
  // Larghezza massima contenuto centrato
  static const double maxContentWidth = 1200.0;

  // Padding standard
  static const double pagePadding = 16.0;

  // Spaziatura tra sezioni
  static const double sectionSpacing = 24.0;

  // Breakpoint responsive
  static const double phoneBreakpoint = 600.0;
  static const double tabletBreakpoint = 800.0;
  static const double shellCompactBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;

  // Dimensioni font titolo pagina
  static const double pageTitleSize = 22.0;

  /// Larghezza massima area contenuto (tutte le pagine con shell).
  static const double shellContentMaxWidth = 1300.0;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phoneBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tabletBreakpoint;

  /// Menu laterale → drawer (telefono e tablet).
  static bool useCompactShell(BuildContext context) =>
      MediaQuery.sizeOf(context).width < shellCompactBreakpoint;

  /// Alias per layout interni (stesso breakpoint dello shell).
  static bool isCompactLayout(BuildContext context) => useCompactShell(context);

  static double pagePaddingFor(BuildContext context) =>
      isPhone(context) ? 8.0 : pagePadding;

  /// Padding pagina: su telefono margini laterali ridotti per usare tutta la larghezza.
  static EdgeInsets pagePaddingInsetsFor(BuildContext context) {
    if (isPhone(context)) {
      return const EdgeInsets.fromLTRB(8, 8, 8, 10);
    }
    return const EdgeInsets.fromLTRB(16, 12, 16, 14);
  }

  static double shellContentMaxWidthFor(BuildContext context) {
    if (isPhone(context)) return double.infinity;
    return shellContentMaxWidth;
  }

  static double pageTitleSizeFor(BuildContext context) =>
      isPhone(context) ? 18.0 : pageTitleSize;

  static double sectionSpacingFor(BuildContext context) =>
      isPhone(context) ? 12.0 : 20.0;

  static double drawerWidthFor(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.85).clamp(280.0, 360.0);
  }

  /// Spazio extra in fondo alle liste scrollabili (banner cookie sovrapposto).
  static double overlayBottomInset(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    final banner = isPhone(context) ? 100.0 : 80.0;
    return safe + banner;
  }

  static EdgeInsets scrollPadding(BuildContext context) {
    final h = pagePaddingFor(context);
    return EdgeInsets.fromLTRB(h, h, h, h + overlayBottomInset(context));
  }

  static double dialogWidth(BuildContext context, {double max = 520}) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < max + 40) return w * 0.92;
    return max;
  }
}
