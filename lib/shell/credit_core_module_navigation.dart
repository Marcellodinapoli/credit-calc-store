import 'package:flutter/material.dart';

/// Route delle pagine aperte dal menù (Form, Job, Area, Sincronizza).
const creditCoreModuleRouteName = 'credit_core_module';

/// Segnala alla shell CreditCalc di mostrare la sezione Creditori al ritorno.
final ValueNotifier<bool> creditCalcReturnToCreditorsRequest =
    ValueNotifier(false);

Route<T> creditCoreModuleRoute<T>(WidgetBuilder builder) {
  return MaterialPageRoute<T>(
    settings: const RouteSettings(name: creditCoreModuleRouteName),
    builder: builder,
  );
}

/// Torna alla schermata Creditori in CreditCalc.
void popToCreditCalcHome(BuildContext context) {
  creditCalcReturnToCreditorsRequest.value = true;
  final navigator = Navigator.of(context);
  if (!navigator.canPop()) return;
  navigator.popUntil(
    (route) => route.settings.name != creditCoreModuleRouteName,
  );
}
