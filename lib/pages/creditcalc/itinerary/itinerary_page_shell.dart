import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../../core/dimensions.dart';
import '../../../core/maintenance_service.dart';
import '../../../services/gestione_menu_badge_service.dart';
import '../../area/personal_area_shell.dart';

class ItineraryPageShell {
  const ItineraryPageShell({this.personalArea = false});

  final bool personalArea;

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
    GestioneMenuBadgeKey? badgeKey,
  }) {
    if (personalArea) {
      return PersonalAreaShell(
        pageTitle: pageTitle,
        gestioneSection: true,
        gestioneBadgeKey: badgeKey,
        maintenanceSection: MaintenanceService.creditCalc,
        body: body,
      );
    }
    return wrapCreditCalcPage(
      pageTitle: pageTitle,
      current: CreditCalcNavItem.tools,
      body: body,
    );
  }

  Widget secondary({
    required String pageTitle,
    required Widget body,
    GestioneMenuBadgeKey? badgeKey,
  }) {
    if (personalArea) {
      return PersonalAreaShell(
        pageTitle: pageTitle,
        gestioneSection: true,
        gestioneBadgeKey: badgeKey,
        maintenanceSection: MaintenanceService.creditCalc,
        body: body,
      );
    }
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: pageTitle,
      current: CreditCalcNavItem.tools,
      body: body,
    );
  }
}
