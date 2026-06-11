import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceNoteField extends StatefulWidget {
  const VoiceNoteField({
    super.key,
    required this.controller,
    this.labelText = 'Note',
    this.maxLines = 3,
  });

  final TextEditingController controller;
  final String labelText;
  final int maxLines;

  @override
  State<VoiceNoteField> createState() => _VoiceNoteFieldState();
}

class _VoiceNoteFieldState extends State<VoiceNoteField> {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize();
    if (mounted) setState(() => _ready = ok);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_ready) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dettatura vocale non disponibile su questo dispositivo.'),
        ),
      );
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    await _speech.listen(
      localeId: 'it_IT',
      listenMode: ListenMode.confirmation,
      onResult: (result) {
        widget.controller.text = result.recognizedWords;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      },
    );
    if (mounted) setState(() => _listening = true);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _listening ? 'Ferma dettatura' : 'Detta nota',
          onPressed: _toggleListening,
          icon: Icon(
            _listening ? Icons.mic : Icons.mic_none_outlined,
            color: _listening ? Colors.red : null,
          ),
        ),
      ),
      maxLines: widget.maxLines,
    );
  }
}
