import 'dart:convert';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cifratura AES dei payload nel database locale (Fase 17).
abstract final class LocalDataCipher {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'credit_calc_local_db_key';
  static enc.Key? _cachedKey;

  static Future<enc.Key> _key() async {
    final cached = _cachedKey;
    if (cached != null) return cached;

    var raw = await _storage.read(key: _keyName);
    if (raw == null || raw.isEmpty) {
      final generated = enc.Key.fromSecureRandom(32);
      raw = base64Encode(generated.bytes);
      await _storage.write(key: _keyName, value: raw);
    }
    final key = enc.Key(base64Decode(raw));
    _cachedKey = key;
    return key;
  }

  static Future<String> encryptJson(String plain) async {
    final key = await _key();
    final iv = enc.IV.fromSecureRandom(16);
    final aes = enc.Encrypter(enc.AES(key));
    final encrypted = aes.encrypt(plain, iv: iv);
    return jsonEncode({
      'v': 1,
      'iv': base64Encode(iv.bytes),
      'data': encrypted.base64,
    });
  }

  static Future<String> decryptJson(String stored) async {
    final parsed = jsonDecode(stored);
    if (parsed is! Map) return stored;
    if (parsed['v'] != 1) return stored;

    final key = await _key();
    final iv = enc.IV(base64Decode(parsed['iv'] as String));
    final aes = enc.Encrypter(enc.AES(key));
    return aes.decrypt64(parsed['data'] as String, iv: iv);
  }
}
