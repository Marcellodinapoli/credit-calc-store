// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/platform/native_audio_helper.dart';
import '../../services/warmup_evaluation_service.dart';
import 'personal_form_shell.dart';


/// -----------------------------------------------------------------------------
/// MODEL
/// -----------------------------------------------------------------------------
class ContestationTrainingItem {
  final String title;
  final String declared;
  final String meaning;
  final String risk;
  final String objective;
  final String response;

  const ContestationTrainingItem({
    required this.title,
    required this.declared,
    required this.meaning,
    required this.risk,
    required this.objective,
    required this.response,
  });
}

/// -----------------------------------------------------------------------------
/// PAGE – ANALISI CONTESTAZIONE
/// -----------------------------------------------------------------------------
class ContestationTrainingPage extends StatefulWidget {
  final ContestationTrainingItem item;

  const ContestationTrainingPage({
    super.key,
    required this.item,
  });

  @override
  State<ContestationTrainingPage> createState() =>
      _ContestationTrainingPageState();
}

class _ContestationTrainingPageState
    extends State<ContestationTrainingPage> {
  int _step = 0;

  // FIREBASE
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // AUDIO
  bool _isRecording = false;
  bool _hasRecording = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _aiResult;
  bool _evaluationPending = false;

  bool get _canCompleteSimulation => _hasRecording;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _restoreProgress();
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE — PROGRESS (SAFE)
  // ---------------------------------------------------------------------------
  String get _progressDocId =>
      '${_auth.currentUser!.uid}_${widget.item.title}';

  Future<void> _saveProgress() async {
    try {
      await _firestore.collection('training_progress').doc(_progressDocId).set({
        'uid': _auth.currentUser!.uid,
        'title': widget.item.title,
        'step': _step,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // 🔒 nessun permesso → ignora
    }
  }

  Future<void> _restoreProgress() async {
    try {
      final snap = await _firestore
          .collection('training_progress')
          .doc(_progressDocId)
          .get();

      if (snap.exists && snap.data()?['step'] != null) {
        setState(() => _step = snap.data()!['step']);
      }
    } catch (_) {
      // 🔒 nessun permesso → ignora
    }
  }

  void _next() {
    if (_step < 5) {
      setState(() => _step++);
      _saveProgress();
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  Color get _contestationColor {
    switch (widget.item.title) {
      case 'Un giorno di ritardo':
      case 'Coobbligato':
        return Colors.green;
      case 'Agenzia debiti':
        return Colors.blue;
      case 'Prodotto difettoso':
      case 'Pagamento generico':
        return Colors.blueGrey;
      case 'Difficoltà economica':
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }

  void _tryFinish() {
    if (_canCompleteSimulation) {
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registra la tua risposta prima di concludere.'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AUDIO — IMPLEMENTAZIONE DOM
  // ---------------------------------------------------------------------------
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      setState(() => _isRecording = false);
      try {
        final bytes = await NativeAudioHelper.stopRecording();
        if (bytes.length < 5000) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registrazione troppo breve, riprova'),
              ),
            );
          }
          return;
        }

        setState(() {
          _hasRecording = true;
          _isProcessing = true;
          _aiResult = null;
          _evaluationPending = false;
        });

        try {
          final result = await _sendToAI(bytes);
          if (!mounted) return;
          setState(() {
            _aiResult = result;
            _isProcessing = false;
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _evaluationPending = true;
          });
        }
      } catch (_) {}
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
      phase: widget.item.title,
      expectedText: widget.item.response,
      phaseExplanation:
          'Contestazione: ${widget.item.declared}\n'
          'Significato: ${widget.item.meaning}\n'
          'Rischio: ${widget.item.risk}\n'
          'Obiettivo: ${widget.item.objective}',
      customerLine: widget.item.declared,
      kind: 'contestation',
    );
  }

  void _playRecording() {
    if (!_hasRecording) return;
    NativeAudioHelper.playRecording();
  }

  // ---------------------------------------------------------------------------
  // STEP CONTENT
  // ---------------------------------------------------------------------------
  String get _stepTitle {
    switch (_step) {
      case 0:
        return "1️⃣ Contestazione dichiarata";
      case 1:
        return "2️⃣ Cosa sta comunicando davvero";
      case 2:
        return "3️⃣ Rischio se gestita male";
      case 3:
        return "4️⃣ Obiettivo dell’operatore";
      case 4:
        return "5️⃣ Linea di risposta corretta";
      case 5:
        return "6️⃣ Simulazione attiva";
      default:
        return "";
    }
  }

  Widget get _stepContent {
    switch (_step) {
      case 0:
        return Text(widget.item.declared,
            style: const TextStyle(fontSize: 16));
      case 1:
        return Text(widget.item.meaning,
            style: const TextStyle(fontSize: 16));
      case 2:
        return Text(widget.item.risk, style: const TextStyle(fontSize: 16));
      case 3:
        return Text(widget.item.objective,
            style: const TextStyle(fontSize: 16));
      case 4:
        return Text(widget.item.response,
            style: const TextStyle(fontSize: 16));
      case 5:
        return _simulationStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // SIMULAZIONE AUDIO
  // ---------------------------------------------------------------------------
  Widget _simulationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Rispondi con la tua voce.",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (widget.item.response.trim().isNotEmpty) ...[
          Text(
            'Linea di risposta corretta (riferimento)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(widget.item.response),
          ),
          const SizedBox(height: 16),
        ],
        Center(
          child: Column(
            children: [
              IconButton(
                iconSize: 64,
                icon: Icon(
                  _isRecording ? Icons.stop_circle : Icons.mic,
                  color: _isRecording ? Colors.red : _contestationColor,
                ),
                onPressed: _toggleRecording,
              ),
              const SizedBox(height: 8),
              const Text(
                "La registrazione non viene salvata né ascoltata da nessuno.\n"
                    "Puoi riascoltarla solo ora, durante questa simulazione.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_hasRecording)
          Center(
            child: FilledButton.icon(
              onPressed: _playRecording,
              icon: const Icon(Icons.play_arrow),
              label: const Text("Riascolta la registrazione"),
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
                'Registrazione ricevuta. Il suggerimento AI sarà disponibile '
                'a breve: puoi comunque concludere la simulazione.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ),
        if (_aiResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggerimento atteso',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                if ((_aiResult!['commento'] ?? '').toString().isNotEmpty)
                  Text(_aiResult!['commento'].toString()),
                if ((_aiResult!['versione_migliorata'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
                  if ((_aiResult!['commento'] ?? '').toString().isNotEmpty)
                    const SizedBox(height: 8),
                  Text(
                    'Esempio di risposta: '
                    '${_aiResult!['versione_migliorata']}',
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(6, (index) {
          final active = index <= _step;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              decoration: BoxDecoration(
                color: active ? _contestationColor : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionBar() {
    final label = _step < 5 ? 'Avanti' : 'Fine';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () {
            if (_step < 5) {
              _next();
            } else {
              _tryFinish();
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: _contestationColor,
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

  /// ---------------------------------------------------------------------------
  /// BUILD
  /// ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PersonalFormShell(
      pageTitle: 'Analisi contestazione',
      bottomBar: _buildActionBar(),
      body: Column(
        children: [
          _buildProgressBar(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              widget.item.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                            color: _contestationColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _stepContent,
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