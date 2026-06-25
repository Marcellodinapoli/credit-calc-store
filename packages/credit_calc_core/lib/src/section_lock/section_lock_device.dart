import 'package:shared_preferences/shared_preferences.dart';

/// Identità locale del dispositivo/browser per distinguere tab e app.
abstract final class SectionLockDevice {
  static const _deviceIdKey = 'credit_calc_section_device_id';

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final now = DateTime.now().microsecondsSinceEpoch;
    final id = 'device-$now-${now.hashCode.abs()}';
    await prefs.setString(_deviceIdKey, id);
    return id;
  }
}
