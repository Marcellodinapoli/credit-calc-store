import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

/// Azioni condivise nella barra superiore dei moduli Form/Job/Area.
abstract final class CreditModuleShellActions {
  static List<Widget> appBarActions(BuildContext context) {
    return const [
      AnnouncementsBellButton(iconColor: Colors.black87),
    ];
  }
}
