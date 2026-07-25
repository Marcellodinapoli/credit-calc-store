import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

/// Tab attiva della shell CreditCalc (fonte unica di verità).
final ValueNotifier<CreditCalcNavItem> creditCalcActiveSection =
    ValueNotifier(CreditCalcNavItem.creditors);

void creditCalcGoToCreditors() {
  creditCalcActiveSection.value = CreditCalcNavItem.creditors;
}

/// Chiude la pagina secondaria restando sulla sezione già attiva.
void popCreditCalcSecondary(BuildContext context) {
  Navigator.of(context, rootNavigator: true).maybePop();
}

/// Alias storico: non forza più Creditori.
void popCreditCalcSecondaryToCreditors(BuildContext context) {
  popCreditCalcSecondary(context);
}
