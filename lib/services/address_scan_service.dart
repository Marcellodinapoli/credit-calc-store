import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'address_text_parser.dart';

/// OCR indirizzo da fotocamera/galleria (Android/iOS).
abstract final class AddressScanService {
  static Future<String?> recognizeFromImagePath(String imagePath) async {
    if (kIsWeb) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final buffer = StringBuffer();
      for (final block in result.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
      }
      final raw = buffer.toString().trim();
      if (raw.isEmpty) return null;
      return AddressTextParser.extractLikelyAddress(raw);
    } finally {
      await recognizer.close();
    }
  }

  static Future<String?> captureAndExtractAddress({
    required ImageSource source,
  }) async {
    if (source == ImageSource.camera) {
      final camera = await Permission.camera.request();
      if (!camera.isGranted) return null;
    }

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (file == null) return null;
    return recognizeFromImagePath(file.path);
  }
}
