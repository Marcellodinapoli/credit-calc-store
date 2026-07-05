import 'package:flutter/material.dart';

import '../offline/models/session_info.dart';

Future<void> showAppSessionConflictDialog(
  BuildContext context, {
  SessionInfo? conflict,
}) {
  final deviceLine = conflict == null
      ? 'un altro dispositivo'
      : conflict.conflictSummary;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Text('Account già in uso'),
      content: Text(
        'Hai già aperto lo stesso account su:\n\n'
        '$deviceLine\n\n'
        'Per usare CreditCalc su questo dispositivo devi uscire '
        'dall\'account sul primo dispositivo.\n\n'
        'Nel frattempo puoi accedere solo alla pagina Sincronizza.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
          child: const Text('Ho capito'),
        ),
      ],
    ),
  );
}
