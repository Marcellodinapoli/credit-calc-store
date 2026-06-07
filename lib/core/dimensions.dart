import 'dart:math' as math;

import 'package:flutter/material.dart';

class Dimensions {
  static const double phoneBreakpoint = 600;
  static const double shellCompactBreakpoint = 900;
  static const double shellContentMaxWidth = 1300;
  static const double pagePadding = 16;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phoneBreakpoint;

  static bool useCompactShell(BuildContext context) =>
      MediaQuery.sizeOf(context).width < shellCompactBreakpoint;

  static EdgeInsets pagePaddingInsetsFor(BuildContext context) {
    if (isPhone(context)) {
      return const EdgeInsets.fromLTRB(8, 8, 8, 10);
    }
    return const EdgeInsets.fromLTRB(16, 12, 16, 14);
  }

  static double pageTitleSizeFor(BuildContext context) =>
      isPhone(context) ? 18 : 22;

  static double sectionSpacingFor(BuildContext context) =>
      isPhone(context) ? 12 : 20;

  static double shellContentMaxWidthFor(BuildContext context) {
    if (isPhone(context)) return double.infinity;
    return shellContentMaxWidth;
  }

  static double drawerWidthFor(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return (w * 0.85).clamp(280, 360);
  }

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 800;

  static double pagePaddingFor(BuildContext context) =>
      isPhone(context) ? 8.0 : pagePadding;

  static double dialogWidth(BuildContext context, {double max = 520}) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < max + 40) return w * 0.92;
    return max;
  }

  /// Spazio sotto i pulsanti per non finire sotto la barra di navigazione Android/iOS.
  static double resolvedBottomInset(BuildContext context) {
    final media = MediaQuery.of(context);
    final reported = math.max(media.viewPadding.bottom, media.padding.bottom);
    if (reported > 0) return reported;

    if (!isPhone(context)) return 0;

    return switch (Theme.of(context).platform) {
      TargetPlatform.android => 48,
      TargetPlatform.iOS => 34,
      _ => 16,
    };
  }

  static double overlayBottomInset(BuildContext context) {
    return resolvedBottomInset(context) + (isPhone(context) ? 12.0 : 8.0);
  }

  static EdgeInsets bottomSafePadding(BuildContext context) {
    return EdgeInsets.only(
      bottom: resolvedBottomInset(context) + (isPhone(context) ? 8.0 : 0),
    );
  }

  static EdgeInsets scrollPadding(BuildContext context) {
    final h = isPhone(context) ? 8.0 : pagePadding;
    return EdgeInsets.fromLTRB(h, h, h, h + overlayBottomInset(context));
  }
}
