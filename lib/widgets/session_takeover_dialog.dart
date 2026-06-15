import 'package:flutter/material.dart';

import '../offline/models/session_info.dart';

Future<bool> showSessionTakeoverDialog(
  BuildContext context,
  SessionInfo existing,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Text('CreditCore già attivo'),
      content: Text(
        'Hai già una sessione aperta su:\n\n'
        '${existing.conflictSummary}\n\n'
        'Vuoi continuare su questo dispositivo?\n\n'
        'L\'altra sessione verrà chiusa automaticamente. CreditCore '
        '(Form, Calc, Job e web) può restare aperto su un solo dispositivo '
        'o browser per volta.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(ctx, rootNavigator: true).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
          child: const Text('Continua qui'),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}
