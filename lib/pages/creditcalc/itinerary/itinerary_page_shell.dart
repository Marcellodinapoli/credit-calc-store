import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../../core/dimensions.dart';

class ItineraryPageShell {
  const ItineraryPageShell();

  /// Padding liste scrollabili: spazio extra sotto per barra gesti / bordo telefono.
  static EdgeInsets listPadding(BuildContext context) {
    return EdgeInsets.fromLTRB(
      16,
      16,
      16,
      Dimensions.overlayBottomInset(context),
    );
  }

  static EdgeInsets headerPadding(BuildContext context) {
    return const EdgeInsets.fromLTRB(16, 8, 16, 0);
  }

  static EdgeInsets bottomPanelMargin(BuildContext context) {
    return EdgeInsets.fromLTRB(
      16,
      0,
      16,
      16 + Dimensions.resolvedBottomInset(context),
    );
  }

  Widget primary({
    required String pageTitle,
    required Widget body,
  }) {
    return wrapCreditCalcPage(
      pageTitle: pageTitle,
      current: CreditCalcNavItem.tools,
      body: body,
    );
  }

  Widget secondary({
    required String pageTitle,
    required Widget body,
  }) {
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: pageTitle,
      current: CreditCalcNavItem.tools,
      body: body,
    );
  }
}
