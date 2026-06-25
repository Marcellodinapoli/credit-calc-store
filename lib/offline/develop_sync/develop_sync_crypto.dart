import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Chiave AES condivisa tra i dispositivi dell'utente (solo in Firestore privato).
abstract final class DevelopSyncCrypto {
  static final _firestore = FirebaseFirestore.instance;
  static final _keyCache = <String, enc.Key>{};

  static DocumentReference<Map<String, dynamic>> _keyRef(String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('develop_sync_private')
          .doc('key');

  static Future<enc.Key> userKey(String userId) async {
    final cached = _keyCache[userId];
    if (cached != null) return cached;

    final ref = _keyRef(userId);
    final snap = await ref.get();
    if (snap.exists) {
      final raw = snap.data()?['value'] as String?;
      if (raw != null && raw.isNotEmpty) {
        final key = enc.Key(base64Decode(raw));
        _keyCache[userId] = key;
        return key;
      }
    }

    final generated = enc.Key.fromSecureRandom(32);
    await ref.set({
      'value': base64Encode(generated.bytes),
      'createdAt': FieldValue.serverTimestamp(),
    });
    _keyCache[userId] = generated;
    return generated;
  }

  static Future<String> encryptPayload(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final key = await userKey(userId);
    final iv = enc.IV.fromSecureRandom(16);
    final aes = enc.Encrypter(enc.AES(key));
    final plain = jsonEncode(payload);
    final encrypted = aes.encrypt(plain, iv: iv);
    return jsonEncode({
      'v': 1,
      'iv': base64Encode(iv.bytes),
      'data': encrypted.base64,
    });
  }

  static Future<Map<String, dynamic>> decryptPayload(
    String userId,
    String stored,
  ) async {
    final parsed = jsonDecode(stored);
    if (parsed is! Map || parsed['v'] != 1) {
      if (parsed is Map<String, dynamic>) return parsed;
      throw FormatException('Payload sync non valido');
    }

    final key = await userKey(userId);
    final iv = enc.IV(base64Decode(parsed['iv'] as String));
    final aes = enc.Encrypter(enc.AES(key));
    final plain = aes.decrypt64(parsed['data'] as String, iv: iv);
    return jsonDecode(plain) as Map<String, dynamic>;
  }

  static void clearCache([String? userId]) {
    if (userId == null) {
      _keyCache.clear();
      return;
    }
    _keyCache.remove(userId);
  }
}
