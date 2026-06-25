import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Identificativo stabile del dispositivo per il sync.
abstract final class DevelopSyncDevice {
  static const _prefKey = 'develop_sync_device_id_v1';

  static String? _cached;

  static Future<String> id() async {
    final cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;

    final prefs = await SharedPreferences.getInstance();
    var stored = prefs.getString(_prefKey);
    if (stored == null || stored.isEmpty) {
      stored = _generateId();
      await prefs.setString(_prefKey, stored);
    }
    _cached = stored;
    return stored;
  }

  static String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
