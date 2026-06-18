import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

abstract final class ConnectivityService {
  static final _connectivity = Connectivity();

  static Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    // Lista vuota: su Windows connectivity_plus può non restituire interfacce.
    final explicitOffline = results.isNotEmpty &&
        results.every((r) => r == ConnectivityResult.none);
    if (explicitOffline && !_shouldProbeDespiteOfflineReport()) {
      return false;
    }
    if (kIsWeb) return !explicitOffline;
    return _probeReachability();
  }

  /// Su Windows il plugin può segnalare offline pur con rete attiva.
  static bool _shouldProbeDespiteOfflineReport() {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  static Future<bool> _probeReachability() async {
    const hosts = ['firebase.google.com', 'www.gstatic.com', 'www.google.com'];
    for (final host in hosts) {
      for (final type in [
        InternetAddressType.any,
        InternetAddressType.IPv4,
      ]) {
        try {
          final lookup = await InternetAddress.lookup(host, type: type)
              .timeout(const Duration(seconds: 4));
          if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) {
            return true;
          }
        } catch (_) {}
      }
    }
    return false;
  }

  static Stream<bool> watchOnline() {
    return _connectivity.onConnectivityChanged.map(
      (results) => results.any((r) => r != ConnectivityResult.none),
    );
  }
}
