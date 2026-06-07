// ignore_for_file: deprecated_member_use
// -----------------------------------------------------------------------------
// CONFIG / IMPORT
// -----------------------------------------------------------------------------
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'personal_form_shell.dart';
import '../../core/platform/native_audio_helper.dart';

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

  const CallTrainingConfig({
    required this.phaseKey,
    required this.sectionTitle,
    required this.color,
    required this.customerLine,
    required this.decodifica,
    required this.spiegazione,
    required this.evaluationCriteria,
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
        decodifica:
            'Hai individuato l’interlocutore corretto: ora devi presentarti '
            'in modo chiaro e professionale, senza ancora entrare nel merito '
            'del debito.',
        spiegazione:
            'Obiettivo: dichiarare chi sei, da quale società chiami e il motivo '
            'generale del contatto. L’iniziativa della formulazione è tua.',
        evaluationCriteria:
            'Presentazione professionale: nome, società e motivo del contatto '
            'senza dettagli aggressivi sul debito.',
      );
    case 'Presentazione_privacy':
      return CallTrainingConfig(
        phaseKey: phaseKey,
        sectionTitle: 'Presentazione privacy',
        color: Colors.blue.shade700,
        customerLine:
            'Sono la moglie, può parlare anche con me. Siamo marito e moglie.',
        decodifica:
            'Interviene una terza persona non titolare del debito. Devi applicare '
            'le regole sulla privacy e sul titolarità del rapporto.',
        spiegazione:
            'Obiettivo: verificare se puoi proseguire con un soggetto diverso '
            'dal debitore (consenso, titolarità, limiti di legge). Non fornire '
            'dati sensibili senza le dovute verifiche.',
        evaluationCriteria:
            'Gestione corretta privacy: non divulgare informazioni, chiedere '
            'autorizzazioni o ricontattare il debitore se necessario.',
      );
    case 'Negoziazione':
      return CallTrainingConfig(
        phaseKey: phaseKey,
        sectionTitle: 'Negoziazione',
        color: Colors.deepPurple.shade600,
        customerLine: 'Salve, mi dica.',
        decodifica:
            'Il debitore ti ascolta: è il momento di condurre la trattativa '
            'mantenendo il controllo della conversazione.',
        spiegazione:
            'Obiettivo: esplorare soluzioni, verificare capacità di pagamento '
            'e orientare verso un accordo concreto. Proponi con la tua formulazione.',
        evaluationCriteria:
            'Negoziazione guidata: domande mirate, proposta di soluzione, tono '
            'professionale e assertivo.',
      );
    case 'Chiusura':
      return CallTrainingConfig(
        phaseKey: phaseKey,
        sectionTitle: 'Chiusura',
        color: Colors.green.shade600,
        customerLine:
            'Va bene, le prometto di pagare la rata più le spese entro il 15/06.',
        decodifica:
            'Il cliente conferma un impegno di pagamento con data: devi '
            'consolidare l’accordo prima di chiudere.',
        spiegazione:
            'Obiettivo: ribadire tutti i dettagli (importo rata, spese, scadenza '
            '15/06), ottenere conferma e salutare in modo professionale.',
        evaluationCriteria:
            'Chiusura corretta: riepilogo di rata, spese, data 15/06, '
            'conferma del cliente e formula di saluto.',
      );
    case 'Approccio':
    default:
      return CallTrainingConfig(
        phaseKey: 'Approccio',
        sectionTitle: 'Approccio',
        color: Colors.orange.shade600,
        customerLine: 'Pronto…',
        decodifica:
            'Il cliente risponde alla chiamata: è il primo contatto. Non parlare '
            'ancora del debito.',
        spiegazione:
            'Obiettivo: verificare identità e disponibilità all’ascolto con '
            'tono neutro e professionale. Decidi tu come formulare la frase.',
        evaluationCriteria:
            'Approccio corretto: saluto, verifica identità (es. signor Rossi) '
            'senza anticipare il recupero crediti.',
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

  bool get _canCompletePhase {
    if (!_hasRecorded) return false;
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
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.dinapolimarcello.it/evaluate'),
    );

    request.fields['phase'] = _config.sectionTitle;
    request.fields['expectedText'] = _config.evaluationCriteria;
    request.fields['phaseExplanation'] =
        'Risposta del cliente: ${_config.customerLine}\n${_config.spiegazione}';
    request.fields['customerLine'] = _config.customerLine;

    request.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        bytes,
        filename: 'audio.m4a',
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 40),
      onTimeout: () {
        throw Exception('Timeout AI backend');
      },
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    final decoded = jsonDecode(response.body);

    return decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded);
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
        if (_evaluationPending && !_isProcessing)
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
                'Registrazione ricevuta. La valutazione automatica e il '
                'suggerimento saranno disponibili a breve: puoi comunque '
                'concludere la simulazione.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ),
        if (_aiResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Builder(
              builder: (context) {
                final score = _extractScore(_aiResult);
                final isOk = score >= _minScoreToPass;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trascrizione: ${_aiResult!['trascrizione'] ?? '-'}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Punteggio: $score',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isOk ? Colors.green : Colors.red,
                      ),
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

    if (!_phasePassed && _attemptCount < _maxAttempts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Punteggio insufficiente. Tentativo $_attemptCount/$_maxAttempts.',
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _onActionPressed,
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
