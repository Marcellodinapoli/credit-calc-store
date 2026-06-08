import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identità persistente del dispositivo per la sessione unica.
abstract final class DeviceIdentityService {
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
    final plugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return (
          type: 'mobile',
          label: '${info.brand} ${info.model}'.trim(),
        );
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return (type: 'mobile', label: info.utsname.machine);
      }
      if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        return (type: 'desktop', label: info.computerName);
      }
      if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        return (type: 'desktop', label: info.computerName);
      }
      if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        return (type: 'desktop', label: info.prettyName);
      }
    } catch (_) {}
    return (type: 'unknown', label: 'Dispositivo');
  }
}
