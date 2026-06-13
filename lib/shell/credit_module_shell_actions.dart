import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../offline/credit_calc_runtime.dart';
import '../pages/creditcalc/credit_calc_settings_page.dart';

/// Azioni condivise nella barra superiore dei moduli Form/Job/Area.
abstract final class CreditModuleShellActions {
  static List<Widget> appBarActions(BuildContext context) {
    return [
      const AnnouncementsBellButton(iconColor: Colors.black87),
      IconButton(
        tooltip: 'Impostazioni',
        onPressed: () => openSettings(context),
        icon: const Icon(Icons.settings),
      ),
    ];
  }

  static Future<void> openSettings(BuildContext context) async {
    if (!CreditCalcRuntime.isReady) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreditCalcSettingsPage(
          modePrefs: CreditCalcRuntime.modePrefs!,
          sessionService: CreditCalcRuntime.sessionService!,
          syncEngine: CreditCalcRuntime.syncEngine!,
        ),
      ),
    );
    if (context.mounted) {
      await CreditCalcRuntime.refreshPendingSyncCount();
    }
  }
}
