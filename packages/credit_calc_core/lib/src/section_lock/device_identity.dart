import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

abstract final class SectionDeviceIdentity {
  static const _deviceIdKey = 'credit_calc_device_id';

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  static Future<({String type, String label})> deviceProfile() async {
    if (kIsWeb) {
      return (type: 'web', label: 'Browser Web');
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return (type: 'mobile', label: 'Telefono o tablet');
      }
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final name = Platform.localHostname;
        return (
          type: 'desktop',
          label: name.isNotEmpty ? name : 'Computer',
        );
      }
    } catch (_) {}
    return (type: 'unknown', label: 'Dispositivo');
  }
}
