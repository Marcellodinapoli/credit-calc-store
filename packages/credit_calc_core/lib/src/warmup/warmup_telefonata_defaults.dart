/// Fasi predefinite warm-up telefonata (BackOffice + app).
abstract final class WarmupTelefonataDefaults {
  static const defaultSystemPrompt =
      'Sei un formatore esperto in recupero crediti e warm-up telefonico '
      'in Italia. Valuta la risposta vocale dell\'operatore rispetto '
      'al contesto e alla linea corretta. Rispondi SOLO in JSON con due campi: '
      'commento (feedback breve e costruttivo in italiano) e versione_migliorata '
      '(esempio di risposta vocale migliorata, 2-4 frasi).';

  static const phaseKeys = [
    'Approccio',
    'Presentazione_standard',
    'Presentazione_privacy',
    'Negoziazione',
    'Chiusura',
  ];

  static Map<String, dynamic> defaultPhase(String phaseKey) {
    return Map<String, dynamic>.from(
      _byKey[phaseKey] ?? _byKey['Approccio']!,
    )..['phaseKey'] = phaseKey;
  }

  static Map<String, Map<String, dynamic>> allDefaultPhases() {
    return {
      for (final key in phaseKeys) key: defaultPhase(key),
    };
  }

  static const _byKey = <String, Map<String, dynamic>>{
    'Approccio': {
      'phaseKey': 'Approccio',
      'sectionTitle': 'Approccio',
      'group': '',
      'order': 0,
      'enabled': true,
      'colorValue': 0xFFFB8C00,
      'customerLine': 'Pronto…',
      'targetPersonName': 'Rossi Andrea',
      'callingOnBehalfOf': '',
      'responseGuidance':
          'Verifica se stai parlando con Rossi Andrea. In questa fase non '
          'presentarti ancora: niente nome, cognome o società.',
      'decodifica':
          'Il cliente risponde alla chiamata: è il primo contatto. Non parlare '
          'ancora del debito.',
      'spiegazione':
          'Obiettivo: capire se l\'interlocutore è il debitore corretto. '
          'Saluto breve e verifica identità, senza presentarti e senza '
          'parlare del debito.',
      'evaluationCriteria':
          'Verifica identità del debitore (es. signor Rossi Andrea) con tono '
          'professionale. Non presentarsi ancora e non anticipare il recupero crediti.',
      'systemPrompt': defaultSystemPrompt,
      'phaseInstruction':
          'IMPORTANTE: in fase Approccio l\'operatore NON deve presentarsi '
          '(no nome, cognome, società). Valuta solo se verifica l\'identità '
          'del debitore.',
    },
    'Presentazione_standard': {
      'phaseKey': 'Presentazione_standard',
      'sectionTitle': 'Presentazione standard',
      'group': 'Presentazione',
      'order': 1,
      'enabled': true,
      'colorValue': 0xFF1E88E5,
      'customerLine': 'Con chi ho il piacere di parlare?',
      'targetPersonName': 'Rossi Andrea',
      'callingOnBehalfOf': 'la società mandante',
      'responseGuidance':
          'Presentati con nome e cognome e indica la società per cui chiami. '
          'Non parlare ancora di insoluti o del debito.',
      'decodifica':
          'Hai individuato l\'interlocutore corretto: ora devi presentarti '
          'in modo chiaro e professionale, senza ancora entrare nel merito '
          'del debito.',
      'spiegazione':
          'Obiettivo: presentarti con nome, cognome e società mandante. '
          'Non anticipare insoluti, pagamenti o comunicazioni sul debito.',
      'evaluationCriteria':
          'Presentazione corretta: nome, cognome e società mandante, tono '
          'professionale. Vietato parlare di insoluti, debiti o scadenze.',
      'systemPrompt': defaultSystemPrompt,
      'phaseInstruction':
          'IMPORTANTE: in fase Presentazione standard l\'operatore deve SOLO '
          'presentarsi (nome, cognome, società mandante). NON deve parlare '
          'di insoluti, debiti, scadenze, comunicazioni amministrative o '
          'motivo del contatto. NON penalizzare l\'assenza del motivo del '
          'contatto: in questa fase non serve. Segnala come errore qualsiasi '
          'riferimento al debito. Nell\'esempio (versione_migliorata) proponi '
          'solo una presentazione breve, senza motivo del contatto.',
    },
    'Presentazione_privacy': {
      'phaseKey': 'Presentazione_privacy',
      'sectionTitle': 'Presentazione privacy',
      'group': 'Presentazione',
      'order': 2,
      'enabled': true,
      'colorValue': 0xFF1565C0,
      'customerLine':
          'Sono la moglie, può parlare anche con me. Siamo marito e moglie.',
      'targetPersonName': 'Rossi Andrea',
      'callingOnBehalfOf': '',
      'responseGuidance':
          'Debitore: Rossi Andrea. Puoi dire al massimo il tuo nome e cognome. '
          'Non indicare per conto di chi chiami. Chiedi un recapito telefonico '
          'o di essere richiamato da Rossi Andrea.',
      'decodifica':
          'Interviene una terza persona, non il debitore Rossi Andrea. Devi '
          'applicare le regole sulla privacy e sul titolarità del rapporto.',
      'spiegazione':
          'Obiettivo: proteggere la privacy verso terzi. Il debitore è '
          'Rossi Andrea. Non divulgare informazioni sensibili. Al massimo '
          'nome e cognome, poi chiedi recapito telefonico o richiamata da '
          'Rossi Andrea.',
      'evaluationCriteria':
          'Gestione privacy corretta: non dire per conto di chi chiami, '
          'non divulgare dati sensibili, al massimo nome e cognome, chiedere '
          'recapito telefonico o richiamata dal debitore.',
      'systemPrompt': defaultSystemPrompt,
      'phaseInstruction':
          'IMPORTANTE: in fase Presentazione privacy l\'operatore NON deve '
          'dire per conto di chi chiama (no società mandante). Può indicare '
          'al massimo nome e cognome. Deve chiedere un recapito telefonico '
          'oppure farsi richiamare dal debitore, senza divulgare informazioni '
          'sensibili a terzi. Nell\'esempio (versione_migliorata) non includere '
          'riferimenti alla società, al debito o al motivo della chiamata.',
    },
    'Negoziazione': {
      'phaseKey': 'Negoziazione',
      'sectionTitle': 'Negoziazione',
      'group': '',
      'order': 3,
      'enabled': true,
      'colorValue': 0xFF5E35B1,
      'customerLine': 'Salve, mi dica.',
      'targetPersonName': 'Rossi Andrea',
      'callingOnBehalfOf': '',
      'responseGuidance':
          'Debitore: Rossi Andrea. Incassa 224 euro complessivi '
          '(200 euro di debito piu 24 euro di spese).',
      'decodifica':
          'Il debitore Rossi Andrea ti ascolta: è il momento di condurre '
          'la trattativa mantenendo il controllo della conversazione.',
      'spiegazione':
          'Obiettivo: richiedere a Rossi Andrea il pagamento di 224 euro '
          '(200 euro di debito piu 24 euro di spese), fissando una scadenza '
          'tra la giornata odierna e al massimo l indomani.',
      'evaluationCriteria':
          'Negoziazione efficace: richiedere il pagamento di 224 euro complessivi '
          '(200 euro di debito piu 24 euro di spese), scadenza entro oggi o al '
          'massimo domani, con richiesta diretta e ferma. Vietate domande sul '
          'bonifico o sulla disponibilita: non deve essere un interrogativo.',
      'systemPrompt': defaultSystemPrompt,
      'phaseInstruction':
          'IMPORTANTE: in fase Negoziazione l\'esempio (versione_migliorata) '
          'deve riportare 224 euro complessivi (200 euro di debito + 24 euro '
          'di spese) e richiedere il pagamento entro oggi o al massimo domani '
          'con tono fermo. NON usare domande tipo \'Può procedere con bonifico?\': '
          'deve essere una richiesta diretta di pagamento, non un\'interrogativa.',
    },
    'Chiusura': {
      'phaseKey': 'Chiusura',
      'sectionTitle': 'Chiusura',
      'group': '',
      'order': 4,
      'enabled': true,
      'colorValue': 0xFF43A047,
      'customerLine':
          'Va bene, le prometto di pagare la rata più le spese entro domani.',
      'targetPersonName': 'Rossi Andrea',
      'callingOnBehalfOf': '',
      'responseGuidance':
          'Debitore: Rossi Andrea. Incassa 224 euro complessivi '
          '(200 euro di debito piu 24 euro di spese). Il debitore ha '
          'fissato il pagamento a domani.',
      'decodifica':
          'Il debitore Rossi Andrea ha fissato il pagamento a domani per '
          '224 euro complessivi (200 euro di debito piu 24 euro di spese): '
          'devi consolidare l\'accordo prima di chiudere.',
      'spiegazione':
          'Obiettivo: ribadire a Rossi Andrea l impegno di 224 euro '
          'complessivi (200 euro di debito piu 24 euro di spese) con '
          'pagamento a domani, ottenere conferma e chiudere '
          'professionalmente.',
      'evaluationCriteria':
          'Chiusura corretta: riepilogo di 224 euro (rata piu spese), '
          'impegno per domani senza data specifica, conferma del cliente '
          'e formula di saluto.',
      'systemPrompt': defaultSystemPrompt,
      'phaseInstruction':
          'IMPORTANTE: in fase Chiusura il commento deve prima ricordare '
          'all\'operatore l\'obiettivo (ribadire impegno di 224 euro, rata '
          'piu spese, pagamento entro domani, conferma e saluto). '
          'Nell\'esempio (versione_migliorata) usa \'domani\' senza data '
          'numerica (no 15/06, no 16/05). Riporta 224 euro complessivi.',
    },
  };
}
