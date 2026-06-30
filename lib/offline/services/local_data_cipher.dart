import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_database_service.dart';

typedef CipherKeyBackupReader = Future<String?> Function();
typedef CipherKeyBackupWriter = Future<void> Function(String keyBase64);

/// Cifratura AES dei payload nel database locale (Fase 17).
abstract final class LocalDataCipher {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _legacyStorage = FlutterSecureStorage();
  static const _keyName = 'credit_calc_local_db_key';
  static const _backupKeyName = 'credit_calc_local_db_key_backup';
  static const _maxHistoryKeys = 8;

  static enc.Key? _cachedKey;
  static Future<enc.Key>? _keyLoadFuture;
  static List<String>? _cachedMaterials;
  static String? _persistedAlternateMaterial;
  static CipherKeyBackupReader? _readDbBackup;
  static CipherKeyBackupWriter? _writeDbBackup;
  static CipherKeyBackupReader? _readKeyHistory;
  static CipherKeyBackupWriter? _writeKeyHistory;

  /// Backup della chiave in `app_meta` (impostato dal bootstrap).
  static void configureBackup({
    CipherKeyBackupReader? read,
    CipherKeyBackupWriter? write,
    CipherKeyBackupReader? readHistory,
    CipherKeyBackupWriter? writeHistory,
  }) {
    _readDbBackup = read;
    _writeDbBackup = write;
    _readKeyHistory = readHistory;
    _writeKeyHistory = writeHistory;
    _cachedMaterials = null;
  }

  /// Precarica la chiave prima delle letture SQLite (es. subito dopo il login).
  static Future<void> warmUp() async {
    await _key();
    await _allKeyMaterials();
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

    final iv = enc.IV(base64Decode(parsed['iv'] as String));
    final cipherText = parsed['data'] as String;

    final primary = await _key();
    try {
      return _decryptWithKey(primary, iv, cipherText);
    } catch (_) {
      // Chiave alternativa solo se quella corrente non decifra il record.
    }

    final materials = await _allKeyMaterials();
    Object? lastError;
    for (final raw in materials) {
      try {
        final key = enc.Key(base64Decode(raw));
        if (listEquals(key.bytes, primary.bytes)) continue;
        final plain = _decryptWithKey(key, iv, cipherText);
        _adoptAlternateKey(key, raw);
        return plain;
      } catch (e) {
        lastError = e;
      }
    }

    throw StateError(
      'Decifratura fallita con ${materials.length} chiavi: $lastError',
    );
  }

  static String _decryptWithKey(enc.Key key, enc.IV iv, String cipherText) {
    final aes = enc.Encrypter(enc.AES(key));
    return aes.decrypt64(cipherText, iv: iv);
  }

  static void _adoptAlternateKey(enc.Key key, String raw) {
    _cachedKey = key;
    if (_persistedAlternateMaterial == raw) return;
    _persistedAlternateMaterial = raw;
    final materials = _cachedMaterials;
    if (materials != null && !materials.contains(raw)) {
      materials.insert(0, raw);
    }
    // Persistenza una sola volta per sessione, non per ogni record letto.
    unawaited(_cacheKeyMaterial(raw));
  }

  static Future<enc.Key> _key() async {
    final cached = _cachedKey;
    if (cached != null) return cached;

    final inflight = _keyLoadFuture;
    if (inflight != null) return inflight;

    final future = _loadKeyOnce();
    _keyLoadFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_keyLoadFuture, future)) {
        _keyLoadFuture = null;
      }
    }
  }

  static Future<enc.Key> _loadKeyOnce() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final materials = await _allKeyMaterials();
      if (materials.isNotEmpty) {
        return _cacheKeyMaterial(materials.first);
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 50 * (attempt + 1)));
      }
    }

    final hasEncryptedData =
        await LocalDatabaseService.instance.hasEncryptedPayloads();
    if (hasEncryptedData) {
      for (var attempt = 0; attempt < 5; attempt++) {
        _cachedMaterials = null;
        await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
        final materials = await _allKeyMaterials();
        if (materials.isNotEmpty) {
          return _cacheKeyMaterial(materials.first);
        }
      }
      debugPrint(
        'LocalDataCipher: dati cifrati presenti ma nessuna chiave recuperabile.',
      );
      throw StateError(
        'Impossibile leggere i dati locali: chiave di cifratura non disponibile.',
      );
    }

    final generated = enc.Key.fromSecureRandom(32);
    final encoded = base64Encode(generated.bytes);
    await _persistKeyMaterial(encoded);
    _cachedKey = generated;
    debugPrint('LocalDataCipher: generata nuova chiave locale (database vuoto).');
    return generated;
  }

  static Future<List<String>> _allKeyMaterials() async {
    final cached = _cachedMaterials;
    if (cached != null) return cached;

    final seen = <String>{};
    final ordered = <String>[];

    void add(String? raw) {
      if (raw == null || raw.isEmpty || !seen.add(raw)) return;
      ordered.add(raw);
    }

    for (final storage in [_legacyStorage, _storage]) {
      try {
        add(await storage.read(key: _keyName));
      } catch (e) {
        debugPrint('LocalDataCipher: lettura chiave primaria fallita: $e');
      }
      try {
        add(await storage.read(key: _backupKeyName));
      } catch (e) {
        debugPrint('LocalDataCipher: lettura backup secure storage fallita: $e');
      }
    }

    try {
      add(await _readDbBackup?.call());
    } catch (e) {
      debugPrint('LocalDataCipher: lettura backup database fallita: $e');
    }

    try {
      final historyRaw = await _readKeyHistory?.call();
      if (historyRaw != null && historyRaw.isNotEmpty) {
        final decoded = jsonDecode(historyRaw);
        if (decoded is List) {
          for (final item in decoded) {
            add(item?.toString());
          }
        }
      }
    } catch (e) {
      debugPrint('LocalDataCipher: lettura storico chiavi fallita: $e');
    }

    _cachedMaterials = ordered;
    return ordered;
  }

  static Future<enc.Key> _cacheKeyMaterial(String raw) async {
    final key = enc.Key(base64Decode(raw));
    _cachedKey = key;
    await _persistKeyMaterial(raw);
    return key;
  }

  static Future<void> _persistKeyMaterial(
    String raw, {
    bool mirrorOnly = false,
  }) async {
    if (!mirrorOnly) {
      for (final storage in [_storage, _legacyStorage]) {
        await storage.write(key: _keyName, value: raw);
        await storage.write(key: _backupKeyName, value: raw);
      }
    } else {
      for (final storage in [_storage, _legacyStorage]) {
        final existing = await storage.read(key: _keyName);
        if (existing == null || existing.isEmpty) {
          await storage.write(key: _keyName, value: raw);
        }
        await storage.write(key: _backupKeyName, value: raw);
      }
    }
    await _mirrorBackups(raw);
    await _appendKeyHistory(raw);
    final materials = _cachedMaterials;
    if (materials != null && !materials.contains(raw)) {
      materials.insert(0, raw);
    }
  }

  static Future<void> _mirrorBackups(String raw) async {
    try {
      await _writeDbBackup?.call(raw);
    } catch (e) {
      debugPrint('LocalDataCipher: backup su database non riuscito: $e');
    }
  }

  static Future<void> _appendKeyHistory(String raw) async {
    final writer = _writeKeyHistory;
    final reader = _readKeyHistory;
    if (writer == null || reader == null) return;

    try {
      final history = <String>[];
      final existingRaw = await reader();
      if (existingRaw != null && existingRaw.isNotEmpty) {
        final decoded = jsonDecode(existingRaw);
        if (decoded is List) {
          for (final item in decoded) {
            final value = item?.toString() ?? '';
            if (value.isNotEmpty && !history.contains(value)) {
              history.add(value);
            }
          }
        }
      }
      if (!history.contains(raw)) {
        history.insert(0, raw);
      } else {
        history.remove(raw);
        history.insert(0, raw);
      }
      while (history.length > _maxHistoryKeys) {
        history.removeLast();
      }
      await writer(jsonEncode(history));
    } catch (e) {
      debugPrint('LocalDataCipher: aggiornamento storico chiavi fallito: $e');
    }
  }
}
