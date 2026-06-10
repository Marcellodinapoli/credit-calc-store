import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Estrae righe di testo da un'immagine (solo Android/iOS).
Future<List<String>> extractVisitLinesFromImage(String imagePath) async {
  if (kIsWeb) return const [];
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return const [];
  }

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
    final lines = <String>{};
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.length >= 2) lines.add(text);
      }
    }
    return lines.toList();
  } finally {
    await recognizer.close();
  }
}
