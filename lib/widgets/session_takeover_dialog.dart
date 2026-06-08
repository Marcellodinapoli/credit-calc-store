import 'package:flutter/material.dart';

import '../offline/models/session_info.dart';

Future<bool> showSessionTakeoverDialog(
  BuildContext context,
  SessionInfo existing,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Sessione già attiva'),
      content: Text(
        'CreditCalc è già in uso su:\n\n'
        '${existing.deviceLabel} (${existing.deviceType})\n\n'
        'Vuoi continuare su questo dispositivo? '
        'L\'altro dispositivo verrà disconnesso e i dati verranno '
        'sincronizzati prima di iniziare.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Continua qui'),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}
