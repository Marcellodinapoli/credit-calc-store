import 'package:flutter/material.dart';

/// Route delle pagine aperte dal menù (Form, Job, Area, Sincronizza).
const creditCoreModuleRouteName = 'credit_core_module';

Route<T> creditCoreModuleRoute<T>(WidgetBuilder builder) {
  return MaterialPageRoute<T>(
    settings: const RouteSettings(name: creditCoreModuleRouteName),
    builder: builder,
  );
}

/// Torna alla schermata principale CreditCalc (es. Lista creditori).
void popToCreditCalcHome(BuildContext context) {
  final navigator = Navigator.of(context);
  if (!navigator.canPop()) return;
  navigator.popUntil(
    (route) => route.settings.name != creditCoreModuleRouteName,
  );
}
