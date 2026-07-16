import 'package:image_picker/image_picker.dart';

import 'address_text_parser.dart';

/// OCR indirizzo: stub per web/desktop (funzionalità solo mobile).
abstract final class AddressScanService {
  static Future<AddressScanResult?> recognizeFromImagePath(String imagePath) async {
    return null;
  }

  static Future<AddressScanResult?> captureAndExtractAddress({
    required ImageSource source,
  }) async {
    return null;
  }
}
