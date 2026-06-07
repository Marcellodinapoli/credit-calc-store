import 'package:flutter/material.dart';

import '../nav/credit_calc_nav.dart';
import 'credit_calc_default_layout.dart';

/// Parametri passati all'host esterno (Planet sidebar o shell calcolatrice).
class CreditCalcPageParams {
  final String pageTitle;
  final Widget body;
  final CreditCalcNavItem? current;
  final bool secondary;

  const CreditCalcPageParams({
    required this.pageTitle,
    required this.body,
    this.current,
    this.secondary = false,
  });
}

typedef CreditCalcPageWrapper = Widget Function(CreditCalcPageParams params);

/// Wrapper registrato da CreditPlanet o dal Recovery Tool desktop.
CreditCalcPageWrapper? creditCalcPageWrapper;

/// Usato dalle pagine CreditCalc al posto di ImpaginazionePrincipale/Secondaria.
Widget wrapCreditCalcPage({
  required String pageTitle,
  required Widget body,
  CreditCalcNavItem? current,
  bool secondary = false,
}) {
  final wrapper = creditCalcPageWrapper;
  if (wrapper != null) {
    return wrapper(
      CreditCalcPageParams(
        pageTitle: pageTitle,
        body: body,
        current: current,
        secondary: secondary,
      ),
    );
  }
  return CreditCalcDefaultLayout(
    pageTitle: pageTitle,
    body: body,
    current: current,
    showBack: secondary,
  );
}
