import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

abstract final class ConnectivityService {
  static final _connectivity = Connectivity();

  static Future<bool> isOnline({Duration? timeout}) async {
    final results = await _connectivity.checkConnectivity();
    // Lista vuota: su Windows connectivity_plus può non restituire interfacce.
    final explicitOffline = results.isNotEmpty &&
        results.every((r) => r == ConnectivityResult.none);
    final hasLink = results.any((r) => r != ConnectivityResult.none);
    if (explicitOffline && !_shouldProbeDespiteOfflineReport()) {
      return false;
    }
    if (kIsWeb) return !explicitOffline;
    final probe = _probeReachability(hasLink: hasLink);
    final maxWait = timeout ?? const Duration(seconds: 6);
    try {
      return await probe.timeout(maxWait);
    } on TimeoutException {
      // Su Windows, se la scheda di rete è attiva ma il DNS è lento, non
      // bloccare l'avvio per minuti.
      return hasLink || results.isEmpty && Platform.isWindows;
    }
  }

  /// Su Windows il plugin può segnalare offline pur con rete attiva.
  static bool _shouldProbeDespiteOfflineReport() {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  static Future<bool> _probeReachability({required bool hasLink}) async {
    const hosts = ['firebase.google.com', 'www.gstatic.com', 'www.google.com'];
    Future<bool> lookupHost(String host) async {
      for (final type in [InternetAddressType.IPv4, InternetAddressType.any]) {
        try {
          final lookup = await InternetAddress.lookup(host, type: type)
              .timeout(const Duration(seconds: 2));
          if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) {
            return true;
          }
        } catch (_) {}
      }
      return false;
    }

    final results = await Future.wait(hosts.map(lookupHost));
    if (results.any((ok) => ok)) return true;
    return hasLink;
  }

  static Stream<bool> watchOnline() {
    return _connectivity.onConnectivityChanged.map(
      (results) => results.any((r) => r != ConnectivityResult.none),
    );
  }
}
