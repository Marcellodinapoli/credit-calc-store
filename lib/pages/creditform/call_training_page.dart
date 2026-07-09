// ignore_for_file: deprecated_member_use
// -----------------------------------------------------------------------------
// CONFIG / IMPORT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';

import '../../core/platform/native_audio_helper.dart';
import '../../services/warmup_evaluation_service.dart';
import 'personal_form_shell.dart';

// -----------------------------------------------------------------------------
// MODEL
// -----------------------------------------------------------------------------
class CallTrainingConfig {
  final String phaseKey;
  final String sectionTitle;
  final Color color;
  final String customerLine;
  final String decodifica;
  final String spiegazione;
  /// Criterio per la valutazione AI (non mostrato come script all'utente).
  final String evaluationCriteria;
  final String? targetPersonName;
  final String? callingOnBehalfOf;
  final String? responseGuidance;

  const CallTrainingConfig({
    required this.phaseKey,
    required this.sectionTitle,
    required this.color,
    required this.customerLine,
    required this.decodifica,
    required this.spiegazione,
    required this.evaluationCriteria,
    this.targetPersonName,
    this.callingOnBehalfOf,
    this.responseGuidance,
  });
}

CallTrainingConfig callTrainingConfigFor(String phaseKey) {
  switch (phaseKey) {
    case 'Presentazione_standard':
      return CallTrainingConfig(
        phaseKey: phaseKey,
        sectionTitle: 'Presentazione standard',
        color: Colors.blue.shade600,
        customerLine: 'Con chi ho il piacere di parlare?',
        targetPersonName: 'Rossi Andrea',
        callingOnBehalfOf: 'la società mandante',
        responseGuidance:
            'Presentati con nome e cognome e indica la società per cui chiami. '
            'Non parlare ancora di insoluti o del debito.',
        decodifica:
            'Hai individuato l’interlocutore corretto: ora devi presentarti '
            'in modo chiaro e professionale, senza ancora entrare nel merito '
            'del debito.',
        spiegazione:
            'Obiettivo: presentarti con nome, cognome e società mandante. '
            'Non anticipare insoluti, pagamenti o comunicazioni sul debito.',
        evaluationCriteria:
            'Presentazione corretta: nome, cognome e società mandante, tono '
            'professionale. Vietato parlare di insoluti, debiti o scadenze.',
      );
    case 'Presentazione_privacy':
      return CallTrainingConfig(
        phaseKey: phaseKey,
        sectionTitle: 'Presentazione privacy',
        color: Colors.blue.shade700,
        targetPersonName: 'Rossi Andrea',
        responseGuidance:
            'Debitore: Rossi Andrea. Puoi dire al massimo il tuo nome e cognome. '
            'Non indicare per conto di chi chiami. Chiedi un recapito telefonico '
            'o di essere richiamato da Rossi Andrea.',
        customerLine:
            'Sono la moglie, può parlare anche con me. Siamo marito e moglie.',
        decodifica:
            'Interviene una terza persona, non il debitore Rossi Andrea. Devi '
            'applicare le regole sulla privacy e sul titolarità del rapporto.',
        spiegazione:
            'Obiettivo: proteggere la privacy verso terzi. Il debitore è '
            'Rossi Andrea. Non divulgare informazioni sensibili. Al massimo '
            'nome e cognome, poi chiedi recapito telefonico o richiamata da '
            'Rossi Andrea.',
        evaluationCriteria:
            'Gestione privacy corretta: non dire per conto di chi chiami, '
            'non divulgare dati sensibili, al massimo nome e cognome, chiedere '
            'recapito telefonico o richiamata dal debitore.',
      );
    case 'Negoziazione':
      return CallTrainingConfig(
        phaseKey: phaseKey,
        sectionTitle: 'Negoziazione',
        color: Colors.deepPurple.shade600,
        targetPersonName: 'Rossi Andrea',
        responseGuidance:
            'Debitore: Rossi Andrea. Incassa 224 euro complessivi '
            '(200 euro di debito piu 24 euro di spese).',
        customerLine: 'Salve, mi dica.',
        decodifica:
            'Il debitore Rossi Andrea ti ascolta: è il momento di condurre '
            'la trattativa mantenendo il controllo della conversazione.',
        spiegazione:
            'Obiettivo: richiedere a Rossi Andrea il pagamento di 224 euro '
            '(200 euro di debito piu 24 euro di spese), fissando una scadenza '
            'tra la giornata odierna e al massimo l indomani.',
        evaluationCriteria:
            'Negoziazione efficace: richiedere il pagamento di 224 euro complessivi '
            '(200 euro di debito piu 24 euro di spese), scadenza entro oggi o al '
            'massimo domani, con richiesta diretta e ferma. Vietate domande sul '
            'bonifico o sulla disponibilita: non deve essere un interrogativo.',
      );
    case 'Chiusura':
      return CallTrainingConfig(
        phaseKey: phaseKey,
        sectionTitle: 'Chiusura',
        color: Colors.green.shade600,
        targetPersonName: 'Rossi Andrea',
        responseGuidance:
            'Debitore: Rossi Andrea. Incassa 224 euro complessivi '
            '(200 euro di debito piu 24 euro di spese). Il debitore ha '
            'fissato il pagamento a domani.',
        customerLine:
            'Va bene, le prometto di pagare la rata più le spese entro domani.',
        decodifica:
            'Il debitore Rossi Andrea ha fissato il pagamento a domani per '
            '224 euro complessivi (200 euro di debito piu 24 euro di spese): '
            'devi consolidare l’accordo prima di chiudere.',
        spiegazione:
            'Obiettivo: ribadire a Rossi Andrea l impegno di 224 euro '
            'complessivi (200 euro di debito piu 24 euro di spese) con '
            'pagamento a domani, ottenere conferma e chiudere '
            'professionalmente.',
        evaluationCriteria:
            'Chiusura corretta: riepilogo di 224 euro (rata piu spese), '
            'impegno per domani senza data specifica, conferma del cliente '
            'e formula di saluto.',
      );
    case 'Approccio':
    default:
      return CallTrainingConfig(
        phaseKey: 'Approccio',
        sectionTitle: 'Approccio',
        color: Colors.orange.shade600,
        customerLine: 'Pronto…',
        targetPersonName: 'Rossi Andrea',
        decodifica:
            'Il cliente risponde alla chiamata: è il primo contatto. Non parlare '
            'ancora del debito.',
        spiegazione:
            'Obiettivo: capire se l\'interlocutore è il debitore corretto. '
            'Saluto breve e verifica identità, senza presentarti e senza '
            'parlare del debito.',
        responseGuidance:
            'Verifica se stai parlando con Rossi Andrea. In questa fase non '
            'presentarti ancora: niente nome, cognome o società.',
        evaluationCriteria:
            'Verifica identità del debitore (es. signor Rossi Andrea) con tono '
            'professionale. Non presentarsi ancora e non anticipare il recupero crediti.',
      );
  }
}

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------
class CallTrainingPage extends StatefulWidget {
  final String phaseKey;

  const CallTrainingPage({
    super.key,
    required this.phaseKey,
  });

  @override
  State<CallTrainingPage> createState() => _CallTrainingPageState();
}

// -----------------------------------------------------------------------------
// STATE
// -----------------------------------------------------------------------------
class _CallTrainingPageState extends State<CallTrainingPage> {
  late final CallTrainingConfig _config;

  int _step = 0;

  bool _isRecording = false;
  bool _hasRecorded = false;

  bool _isProcessing = false;
  Map<String, dynamic>? _aiResult;
  bool _evaluationPending = false;

  int _attemptCount = 0;
  static const int _minScoreToPass = 70;
  static const int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    _config = callTrainingConfigFor(widget.phaseKey);
    _attemptCount = 0;
  }

  void _nextStep() {
    if (_step < 3) {
      setState(() => _step++);
    }
  }

  void _previousStep() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  int _extractScore(Map<String, dynamic>? result) {
    if (result == null) return 0;

    final score = result['score'];

    if (score is int) return score;
    if (score is double) return score.round();
    if (score is String) return int.tryParse(score) ?? 0;

    return 0;
  }

  bool get _phasePassed {
    final score = _extractScore(_aiResult);
    return score >= _minScoreToPass;
  }

  bool get _requiresAiBeforeFinish => _config.targetPersonName != null;

  bool get _canCompletePhase {
    if (!_hasRecorded) return false;
    if (_requiresAiBeforeFinish) {
      return _aiResult != null && !_isProcessing;
    }
    return _phasePassed ||
        _attemptCount >= _maxAttempts ||
        _evaluationPending;
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      setState(() => _isRecording = false);
      try {
        final bytes = await NativeAudioHelper.stopRecording();
        if (bytes.length < 5000) {
          debugPrint('Audio troppo corto (${bytes.length} bytes)');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registrazione troppo breve, riprova')),
            );
          }
          return;
        }

        setState(() {
          _hasRecorded = true;
          _isProcessing = true;
          _aiResult = null;
          _evaluationPending = false;
        });

        try {
          final result = await _sendToAI(bytes);
          if (!mounted) return;
          final score = _extractScore(result);
          setState(() {
            _aiResult = result;
            _isProcessing = false;
            if (score < _minScoreToPass && _attemptCount < _maxAttempts) {
              _attemptCount++;
            }
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _evaluationPending = true;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore registrazione: $e')),
          );
        }
      }
      return;
    }

    try {
      await NativeAudioHelper.startRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microfono non disponibile: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _sendToAI(List<int> bytes) async {
    return WarmupEvaluationService.evaluate(
      audioBytes: bytes,
      phase: _config.sectionTitle,
      expectedText: _config.evaluationCriteria,
      phaseExplanation:
          'Risposta del cliente: ${_config.customerLine}\n${_config.spiegazione}',
      customerLine: _config.customerLine,
      kind: 'warmup',
    );
  }

  void _playRecording() {
    NativeAudioHelper.playRecording();
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return '1️⃣ ${_config.sectionTitle} – Risposta del cliente';
      case 1:
        return '2️⃣ Cosa sta accadendo davvero';
      case 2:
        return '3️⃣ Cosa devi fare';
      case 3:
        return '4️⃣ Simulazione attiva';
      default:
        return '';
    }
  }

  Widget _userResponseBox({double fontSize = 16}) {
    final transcription = (_aiResult?['trascrizione'] ?? '').toString().trim();
    final isPlaceholder = transcription.isEmpty && !_isProcessing;
    final text = _isProcessing
        ? 'Trascrizione in corso…'
        : isPlaceholder
            ? 'La tua risposta vocale apparirà qui dopo la registrazione.'
            : '«$transcription»';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPlaceholder
            ? Colors.grey.shade100
            : _config.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaceholder
              ? Colors.grey.shade300
              : _config.color.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
          color: isPlaceholder ? Colors.black45 : Colors.black87,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _aiEvaluationCard() {
    final commento = (_aiResult!['commento'] ?? '').toString().trim();
    final versione = (_aiResult!['versione_migliorata'] ?? '').toString().trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggerimento AI',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          if (commento.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(commento, style: const TextStyle(height: 1.45)),
          ],
          if (versione.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Esempio di risposta: $versione',
              style: const TextStyle(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _customerLineBox({double fontSize = 16}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _config.color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '«${_config.customerLine}»',
        style: TextStyle(
          fontSize: fontSize,
          fontStyle: FontStyle.italic,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(4, (index) {
          final active = index <= _step;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              decoration: BoxDecoration(
                color: active ? _config.color : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_step == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Il cliente (o l’interlocutore) apre così la conversazione:',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 12),
          _customerLineBox(),
          const SizedBox(height: 12),
          const Text(
            'Nella simulazione risponderai con le tue parole, senza script suggerito.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      );
    }

    if (_step == 1) {
      return Text(
        _config.decodifica,
        style: const TextStyle(fontSize: 16, height: 1.45),
      );
    }

    if (_step == 2) {
      return Text(
        _config.spiegazione,
        style: const TextStyle(fontSize: 16, height: 1.45),
      );
    }

    // Step 3 — simulazione
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rispondi con la tua voce.',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ascolta la replica del cliente e registra la tua risposta: '
          'nessuna frase predefinita, decidi tu come intervenire.',
          style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (_config.targetPersonName != null) ...[
          Text(
            _config.phaseKey.startsWith('Presentazione')
                ? 'Debitore: ${_config.targetPersonName}'
                : 'Persona da contattare: ${_config.targetPersonName}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _config.color,
            ),
          ),
          if (_config.responseGuidance != null) ...[
            const SizedBox(height: 8),
            Text(
              _config.responseGuidance!,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ] else if (_config.callingOnBehalfOf != null) ...[
            const SizedBox(height: 8),
            Text(
              'Presentati con il tuo nome e cognome, indicando che chiami '
              'per conto di ${_config.callingOnBehalfOf}.',
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ],
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Icon(Icons.record_voice_over, color: _config.color, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Cliente / interlocutore',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _customerLineBox(fontSize: 17),
        if (_config.targetPersonName != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.mic, color: _config.color, size: 20),
              const SizedBox(width: 8),
              const Text(
                'La tua risposta',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _userResponseBox(fontSize: 17),
        ],
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              IconButton(
                iconSize: 64,
                icon: Icon(
                  _isRecording ? Icons.stop_circle : Icons.mic,
                  color: _isRecording ? Colors.red : _config.color,
                ),
                onPressed: _toggleRecording,
              ),
              const SizedBox(height: 8),
              Text(
                _isRecording
                    ? 'Registrazione in corso…'
                    : (_hasRecorded
                        ? 'Tocca per registrare di nuovo'
                        : 'Tocca per registrare la tua risposta'),
                style: TextStyle(
                  fontSize: 13,
                  color: _isRecording ? Colors.red : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'La registrazione non viene salvata né ascoltata da nessuno.\n'
                'Puoi riascoltarla solo ora, durante questa simulazione.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        if (_hasRecorded)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                onPressed: _playRecording,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Riascolta la registrazione'),
              ),
            ),
          ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Analisi in corso...'),
              ],
            ),
          ),
        if (_evaluationPending && !_isProcessing && !_requiresAiBeforeFinish)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                'Registrazione ricevuta. Il Suggerimento AI e il '
                'suggerimento saranno disponibili a breve: puoi comunque '
                'concludere la simulazione.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ),
        if (_aiResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _requiresAiBeforeFinish
                ? _aiEvaluationCard()
                : Builder(
              builder: (context) {
                final score = _extractScore(_aiResult);
                final isOk = score >= _minScoreToPass;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trascrizione: ${_aiResult!['trascrizione'] ?? '-'}',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Professionalità: ${_aiResult!['professionalita'] ?? 0}',
                    ),
                    Text('Efficacia: ${_aiResult!['efficacia'] ?? 0}'),
                    Text('Naturalezza: ${_aiResult!['naturalezza'] ?? 0}'),
                    const SizedBox(height: 12),
                    if ((_aiResult!['errori'] as List?)?.isNotEmpty ?? false)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Errori:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          ...(_aiResult!['errori'] as List)
                              .map((e) => Text('• $e')),
                          const SizedBox(height: 8),
                        ],
                      ),
                    if ((_aiResult!['commento'] ?? '').toString().isNotEmpty)
                      Text('Suggerimento: ${_aiResult!['commento'] ?? ''}'),
                    if ((_aiResult!['versione_migliorata'] ?? '')
                        .toString()
                        .isNotEmpty)
                      Text(
                        'Esempio di risposta: '
                        '${_aiResult!['versione_migliorata'] ?? ''}',
                      ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOk
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isOk
                            ? '✔ Risposta adeguata'
                            : '✖ Risposta da migliorare',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isOk ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isOk
                          ? 'Puoi proseguire.'
                          : _attemptCount >= _maxAttempts
                              ? 'Tentativi terminati. Puoi proseguire comunque.'
                              : 'Tentativo $_attemptCount/$_maxAttempts. '
                                  'Puoi registrare di nuovo per migliorare.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isOk
                            ? Colors.green
                            : (_attemptCount >= _maxAttempts
                                ? Colors.orange
                                : Colors.red),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  void _revealCompletionRequirements() {
    if (!_hasRecorded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registra la tua risposta prima di concludere.'),
        ),
      );
      return;
    }

    if (_requiresAiBeforeFinish) {
      if (_isProcessing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendi il completamento del Suggerimento AI.'),
          ),
        );
        return;
      }
      if (_aiResult == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'È necessario il Suggerimento AI prima di concludere.',
            ),
          ),
        );
      }
      return;
    }

    if (!_phasePassed && _attemptCount < _maxAttempts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Risposta da migliorare. Tentativo $_attemptCount/$_maxAttempts.',
          ),
        ),
      );
    }
  }

  void _onActionPressed() {
    if (_step < 3) {
      _nextStep();
      return;
    }

    if (_canCompletePhase) {
      Navigator.pop(context, true);
    } else {
      _revealCompletionRequirements();
    }
  }

  Widget _buildActionBar() {
    final label = _step < 3 ? 'Avanti' : 'Fine';
    final enabled = _step < 3 || _canCompletePhase;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                child: const Text('Indietro'),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: FilledButton(
              onPressed: enabled ? _onActionPressed : null,
              style: FilledButton.styleFrom(
                backgroundColor: _config.color,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                elevation: 2,
              ),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PersonalFormShell(
      pageTitle: 'Telefonata – ${_config.sectionTitle}',
      bottomBar: _buildActionBar(),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stepTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _config.color,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStepContent(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
