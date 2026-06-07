import 'package:flutter/foundation.dart';

/// Piattaforme con push FCM nativo (Android, iOS, macOS).
bool get supportsNativeFcmPush {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// Windows desktop: notifiche locali via Firestore (FCM non supportato).
bool get supportsDesktopLocalPush {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows;
}

String get pushPlatformLabel {
  if (supportsNativeFcmPush) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      _ => 'android',
    };
  }
  if (supportsDesktopLocalPush) return 'windows';
  return 'other';
}
