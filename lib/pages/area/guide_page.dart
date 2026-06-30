import 'package:flutter/material.dart';

import '../../core/dimensions.dart';
import 'personal_area_shell.dart';

class _GuideEntry {
  const _GuideEntry({required this.title, required this.text});

  final String title;
  final String text;
}

const _guideEntries = <_GuideEntry>[
  _GuideEntry(
    title: 'Analisi telefonata',
    text:
        'Suggerimenti e leve negoziali sulla base della pratica in corso.',
  ),
  _GuideEntry(
    title: 'Appuntamenti',
    text:
        'Agenda giornaliera con visite programmate, import da provvigioni e stato delle pratiche.',
  ),
  _GuideEntry(
    title: 'Assistenza diretta',
    text:
        'Apri ticket di supporto, allega documenti e segui le risposte del team.',
  ),
  _GuideEntry(
    title: 'Attività',
    text:
        'Compiti e follow-up da completare, con scadenza opzionale.',
  ),
  _GuideEntry(
    title: 'Calcolatrice',
    text: 'Calcoli rapidi durante la trattativa con il debitore.',
  ),
  _GuideEntry(
    title: 'Collaboratori',
    text:
        'Gestione collaboratori aziendali, formazione assegnata e monitoraggio attività.',
  ),
  _GuideEntry(
    title: 'Community',
    text:
        'Discussioni tra utenti: apri topic, commenta e confrontati con la community.',
  ),
  _GuideEntry(
    title: 'Contestazioni warm-up',
    text:
        'Backoffice: gestione prompt e risposte per le contestazioni nel warm-up.',
  ),
  _GuideEntry(
    title: 'Corsi',
    text:
        'Percorsi formativi con video, quiz e materiali; il completamento aggiorna i progressi.',
  ),
  _GuideEntry(
    title: 'Coupon registrazione',
    text:
        'Backoffice: creazione e gestione coupon per registrazione e accesso ai piani.',
  ),
  _GuideEntry(
    title: 'Creditori',
    text:
        'Anagrafica creditori, fasce PDR, coordinate di pagamento e metodi accettati.',
  ),
  _GuideEntry(
    title: 'Gestione lavori',
    text:
        'Pubblicazione offerte, candidature ricevute e gestione del recruiting aziendale.',
  ),
  _GuideEntry(
    title: 'I miei dati',
    text:
        'Consulta e aggiorna anagrafica, contatti e impostazioni del profilo.',
  ),
  _GuideEntry(
    title: 'I miei progressi',
    text:
        'Avanzamento nei corsi, quiz svolti e risultati della formazione.',
  ),
  _GuideEntry(
    title: 'Il mio piano',
    text:
        'Piano attuale, limiti d\'uso, consumi e cambio o upgrade abbonamento.',
  ),
  _GuideEntry(
    title: 'Imposta provvigioni',
    text:
        'Configura aliquote, soglie e regole di calcolo delle provvigioni per creditore.',
  ),
  _GuideEntry(
    title: 'Impostazioni',
    text:
        'Stato connessione, sessione sul dispositivo e dati CreditCalc salvati in locale.',
  ),
  _GuideEntry(
    title: 'Incassi effettuati',
    text:
        'Anteprima provvigioni del mese ed elenco completo delle pratiche incassate.',
  ),
  _GuideEntry(
    title: 'Inserisci provvigioni',
    text: 'Registra un nuovo incasso e le relative provvigioni.',
  ),
  _GuideEntry(
    title: 'Le mie candidature',
    text: 'Offerte a cui ti sei candidato e stato delle candidature.',
  ),
  _GuideEntry(
    title: 'Monitoraggio rata',
    text: 'Scadenze PDR e collegamento con l\'agenda degli appuntamenti.',
  ),
  _GuideEntry(
    title: 'Notifiche',
    text:
        'Annunci dalla piattaforma (campanella) e preferenze push, inclusi promemoria itinerario.',
  ),
  _GuideEntry(
    title: 'Offerte di lavoro',
    text: 'Esplora le posizioni aperte e candidati alle offerte disponibili.',
  ),
  _GuideEntry(
    title: 'Piani FREE / PLUS / ENTERPRISE',
    text:
        'Backoffice: testi, prezzi, elenco limiti e valori operativi dei piani individuali.',
  ),
  _GuideEntry(
    title: 'Pianificazione territoriale',
    text:
        'Mappa con visite geolocalizzate e percorsi sul territorio.',
  ),
  _GuideEntry(
    title: 'Piano di rientro',
    text: 'Simula rate e scadenze per il rientro del debito.',
  ),
  _GuideEntry(
    title: 'Privacy e consensi',
    text:
        'Consulta e aggiorna consensi privacy e trattamento dati personali.',
  ),
  _GuideEntry(
    title: 'Promemoria',
    text: 'Avvisi programmati per richiami e scadenze importanti.',
  ),
  _GuideEntry(
    title: 'Prompt analisi telefonata',
    text:
        'Backoffice: configurazione del prompt AI per l\'analisi delle telefonate.',
  ),
  _GuideEntry(
    title: 'Prompt ricerca normativa',
    text:
        'Backoffice: configurazione del prompt per la ricerca normativa semplificata.',
  ),
  _GuideEntry(
    title: 'Recensione',
    text: 'Ripasso guidato dei contenuti formativi già seguiti.',
  ),
  _GuideEntry(
    title: 'Ricerca normativa',
    text:
        'Domande su normativa e recupero crediti con risposta assistita da AI.',
  ),
  _GuideEntry(
    title: 'Riscontro backoffice',
    text:
        'Piani sviluppati in attesa di approvazione o incasso da parte del backoffice.',
  ),
  _GuideEntry(
    title: 'Role Play',
    text:
        'Simulazioni vocali di trattative per allenare gestione obiezioni e chiusure.',
  ),
  _GuideEntry(
    title: 'Salvati',
    text: 'Offerte di lavoro salvate per consultarle in seguito.',
  ),
  _GuideEntry(
    title: 'Saldo e stralcio',
    text:
        'Valuta proposte di saldo e stralcio con confronto tra scenari.',
  ),
  _GuideEntry(
    title: 'Statistiche e confronti',
    text: 'Andamento mensile e annuale di incassi e provvigioni.',
  ),
  _GuideEntry(
    title: 'Storico visite',
    text: 'Riepilogo delle visite effettuate per mese e zona territoriale.',
  ),
  _GuideEntry(
    title: 'Utenti associati',
    text:
        'Gestione utenti collegati all\'account azienda e relativi ruoli.',
  ),
  _GuideEntry(
    title: 'Warm-up',
    text:
        'Esercizi guidati sulle fasi della telefonata e gestione delle contestazioni.',
  ),
  _GuideEntry(
    title: 'WhatsApp e email',
    text: 'Modelli di messaggio per contattare il debitore.',
  ),
];

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  static List<_GuideEntry> get _sortedEntries {
    final entries = [..._guideEntries];
    entries.sort((a, b) => a.title.compareTo(b.title));
    return entries;
  }

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
            for (final entry in _sortedEntries)
              _section(
                context,
                title: entry.title,
                text: entry.text,
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
