import 'package:flutter/foundation.dart';

/// Funzioni pensate per smartphone (GPS, fotocamera, OCR).
abstract final class MobileAppFeature {
  static bool get isActive {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
