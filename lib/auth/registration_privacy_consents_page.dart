import 'package:flutter/material.dart';

abstract final class _RegistrationLegalTheme {
  static const accent = Color(0xFF0A66C2);
  static const body = Color(0xFFE8E8E8);
}

const String registrationPrivacyConsentsVersion = '2025';

const String registrationPrivacyConsentsText = '''
PRIVACY POLICY E CONSENSI

La presente informativa descrive le modalità di trattamento dei dati personali
nell'ambito dei servizi CreditCore, ai sensi del Regolamento UE 2016/679 (GDPR).

1. Titolare del trattamento
Il titolare del trattamento è il gestore della piattaforma CreditCore.

2. Tipologia di dati trattati
Possono essere trattati i seguenti dati:
• dati identificativi (nome, cognome, email, ragione sociale, Partita IVA);
• dati di utilizzo della piattaforma (accessi, preferenze, progressi);
• dati tecnici (indirizzo IP, tipo di dispositivo, informazioni di navigazione).

3. Finalità del trattamento
I dati personali sono trattati per:
• consentire la registrazione, l'accesso e l'utilizzo dei servizi;
• gestire l'account e le funzionalità collegate;
• fornire supporto e assistenza;
• adempiere ad obblighi legali e di sicurezza.

4. Base giuridica del trattamento
Il trattamento avviene sulla base del consenso dell'utente, dell'esecuzione di un
contratto o di obblighi di legge.

5. Conservazione dei dati
I dati sono conservati per il tempo strettamente necessario al raggiungimento
delle finalità indicate o secondo quanto previsto dalla normativa vigente.

6. Condivisione dei dati
I dati non vengono diffusi. Possono essere condivisi solo con soggetti autorizzati
esclusivamente per le finalità indicate e nel rispetto della normativa applicabile.

7. Diritti dell'utente
L'utente può esercitare in qualsiasi momento i diritti di accesso, rettifica,
cancellazione, limitazione e opposizione al trattamento, nonché il diritto alla
portabilità dei dati.

8. Cookie e consensi
Al primo accesso puoi gestire cookie tecnici, statistici e di marketing tramite
le impostazioni disponibili nella piattaforma. Le scelte restano memorizzate sul
dispositivo e possono essere modificate in qualsiasi momento dalla sezione
«Privacy e consensi» dell'area personale.

9. Modifica delle preferenze
Le preferenze privacy possono essere aggiornate in qualsiasi momento dalla sezione
«Privacy e consensi» dell'area personale.

Ultimo aggiornamento: $registrationPrivacyConsentsVersion
''';

class RegistrationPrivacyConsentsPage extends StatefulWidget {
  const RegistrationPrivacyConsentsPage({super.key});

  @override
  State<RegistrationPrivacyConsentsPage> createState() =>
      _RegistrationPrivacyConsentsPageState();
}

class _RegistrationPrivacyConsentsPageState
    extends State<RegistrationPrivacyConsentsPage> {
  final _scrollController = ScrollController();

  bool _reachedBottom = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final atBottom =
        position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 24;

    if (atBottom != _reachedBottom) {
      setState(() => _reachedBottom = atBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RegistrationLegalTheme.body,
      appBar: AppBar(
        title: const Text('Privacy e consensi'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leggi l\'informativa completa. Per accettare, scorri fino in fondo.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      registrationPrivacyConsentsText,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            elevation: 8,
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_reachedBottom)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Scorri fino alla fine del documento per abilitare il consenso.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    CheckboxListTile(
                      value: _accepted,
                      onChanged: _reachedBottom
                          ? (value) => setState(() => _accepted = value ?? false)
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Ho letto e accetto l\'informativa sulla privacy e i consensi',
                        style: TextStyle(fontSize: 14, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _accepted
                          ? () => Navigator.pop(context, true)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _RegistrationLegalTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Conferma e torna alla registrazione'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
