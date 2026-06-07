import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Progetto Firebase CreditCore (creditform-d505d).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('CreditCalc non supporta la piattaforma web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return shared;
      default:
        throw UnsupportedError(
          'Firebase non configurato per $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyALeedNoxxo1sTVo_j53MmUcXtofQwls48',
    appId: '1:418457726672:android:a90bd5726277915793f8d5',
    messagingSenderId: '418457726672',
    projectId: 'creditform-d505d',
    storageBucket: 'creditform-d505d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCgCnuQkrW6YE4VSaoqhzngn_5iJ8LUO2A',
    appId: '1:418457726672:ios:0e0da5c3dfd8c9f593f8d5',
    messagingSenderId: '418457726672',
    projectId: 'creditform-d505d',
    storageBucket: 'creditform-d505d.firebasestorage.app',
    iosBundleId: 'com.creditcore.creditcalc',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCgCnuQkrW6YE4VSaoqhzngn_5iJ8LUO2A',
    appId: '1:418457726672:ios:0e0da5c3dfd8c9f593f8d5',
    messagingSenderId: '418457726672',
    projectId: 'creditform-d505d',
    storageBucket: 'creditform-d505d.firebasestorage.app',
    iosBundleId: 'com.creditcore.creditcalc',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCsjtmEM78L8qPEPolG5kIFyTCv0RVbXSo',
    appId: '1:418457726672:web:1b3f95595cd7a91893f8d5',
    messagingSenderId: '418457726672',
    projectId: 'creditform-d505d',
    authDomain: 'creditform-d505d.firebaseapp.com',
    storageBucket: 'creditform-d505d.firebasestorage.app',
  );

  /// Linux e fallback generico (senza FCM nativo).
  static const FirebaseOptions shared = FirebaseOptions(
    apiKey: 'AIzaSyDvg-vsDo-8sFzo6jVbeUWrRPEyFreO32I',
    appId: '1:418457726672:web:4d0d18604a93fbdd93f8d5',
    messagingSenderId: '418457726672',
    projectId: 'creditform-d505d',
    authDomain: 'creditform-d505d.firebaseapp.com',
    storageBucket: 'creditform-d505d.firebasestorage.app',
  );
}
