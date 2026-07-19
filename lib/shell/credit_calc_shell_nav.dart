import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

/// Tab attiva della shell CreditCalc (fonte unica di verità).
final ValueNotifier<CreditCalcNavItem> creditCalcActiveSection =
    ValueNotifier(CreditCalcNavItem.creditors);

void creditCalcGoToCreditors() {
  creditCalcActiveSection.value = CreditCalcNavItem.creditors;
}

/// Torna a Creditori, poi chiude la pagina secondaria.
void popCreditCalcSecondaryToCreditors(BuildContext context) {
  creditCalcGoToCreditors();
  Navigator.of(context, rootNavigator: true).maybePop();
}
