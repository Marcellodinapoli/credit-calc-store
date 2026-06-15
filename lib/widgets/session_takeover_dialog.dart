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
        'Vuoi usare CreditCore su questo dispositivo?\n\n'
        'L\'altra sessione verrà chiusa automaticamente. Puoi restare '
        'connesso su un solo browser o dispositivo per volta '
        '(web CreditPlanet, app mobile o app desktop).',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(ctx, rootNavigator: true).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
          child: const Text('Usa qui'),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}
