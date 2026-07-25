import 'package:flutter/material.dart';

/// Route delle pagine aperte dal menù (Form, Job, Area, Sincronizza).
const creditCoreModuleRouteName = 'credit_core_module';

/// Segnala alla shell CreditCalc di tornare a Creditori (uso esplicito, raro).
final ValueNotifier<bool> creditCalcReturnToCreditorsRequest =
    ValueNotifier(false);

Route<T> creditCoreModuleRoute<T>(WidgetBuilder builder) {
  return MaterialPageRoute<T>(
    settings: const RouteSettings(name: creditCoreModuleRouteName),
    builder: builder,
  );
}

/// Chiude Form/Job/Area/Sincronizza e torna a CreditCalc
/// sulla sezione già attiva (non forza Creditori).
void popToCreditCalcHome(BuildContext context) {
  final navigator = Navigator.of(context);
  if (!navigator.canPop()) return;
  navigator.popUntil(
    (route) => route.settings.name != creditCoreModuleRouteName,
  );
}
