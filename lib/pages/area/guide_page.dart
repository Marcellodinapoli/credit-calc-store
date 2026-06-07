import 'package:flutter/material.dart';

import '../../core/dimensions.dart';
import 'personal_area_shell.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: "Guida all'utilizzo",
      body: SingleChildScrollView(
        padding: Dimensions.scrollPadding(context),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informazioni utili per orientarti e usare correttamente la piattaforma.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                _section(
                  context,
                  title: 'Cos’è questa piattaforma',
                  text:
                  'Questa piattaforma ti permette di seguire percorsi formativi, '
                      'monitorare i tuoi progressi, partecipare alla community e '
                      'accedere ai servizi riservati in modo semplice e guidato.',
                ),

                _section(
                  context,
                  title: 'Navigazione',
                  text:
                  'Utilizza il menù principale per spostarti tra le sezioni. '
                      'Ogni area è pensata per svolgere una funzione specifica '
                      '(formazione, progressi, community, dati personali).',
                ),

                _section(
                  context,
                  title: 'Corsi e formazione',
                  text:
                  'All’interno dei corsi troverai video, quiz ed eventuali allegati. '
                      'Il completamento delle attività aggiorna automaticamente '
                      'i tuoi progressi.',
                ),

                _section(
                  context,
                  title: 'Quiz e progressi',
                  text:
                  'I quiz servono a verificare la comprensione dei contenuti. '
                      'I risultati vengono salvati e sono consultabili nella '
                      'sezione dedicata ai progressi.',
                ),

                _section(
                  context,
                  title: 'Community e supporto',
                  text:
                  'La community consente di confrontarti con altri utenti. '
                      'Per problemi o richieste puoi usare gli strumenti di supporto '
                      'presenti nella piattaforma.',
                ),

                _section(
                  context,
                  title: 'Dati personali',
                  text:
                  'Nell’area personale puoi consultare e aggiornare i tuoi dati. '
                      'Le modifiche vengono applicate in modo immediato.',
                ),
              ],
            ),
      ),
    );
  }

  Widget _section(
      BuildContext context, {
        required String title,
        required String text,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
