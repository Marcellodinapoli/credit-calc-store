import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/sync_record_status.dart';
import '../sqflite_desktop_init.dart';
import '../utils/firestore_json_codec.dart';
import 'local_data_cipher.dart';
class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  Database? _db;

  Future<Database> get database async {
    await ensureSqfliteDesktopInitialized();
    final existing = _db;
    if (existing != null) return existing;

    final options = OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_records (
            id TEXT NOT NULL,
            collection TEXT NOT NULL,
            user_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            server_updated_at INTEGER,
            sync_status TEXT NOT NULL,
            origin TEXT NOT NULL,
            PRIMARY KEY (collection, id)
          )
        ''');
        await db.execute('''
          CREATE TABLE app_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_local_records_user ON local_records(user_id)',
        );
        await db.execute(
          'CREATE INDEX idx_local_records_sync ON local_records(sync_status)',
        );
      },
    );

    Object? lastError;
    for (final path in await _dbPathCandidates()) {
      try {
        debugPrint('LocalDatabaseService: apertura database in $path');
        final Database db;
        if (isSqfliteDesktopPlatform) {
          db = await databaseFactoryFfi.openDatabase(path, options: options);
        } else {
          db = await openDatabase(
            path,
            version: options.version,
            onCreate: options.onCreate,
          );
        }
        _db = db;
        return db;
      } catch (e, st) {
        lastError = e;
        debugPrint(
          'LocalDatabaseService: apertura fallita ($path): $e\n$st',
        );
      }
    }

    throw StateError(
      'Impossibile aprire il database locale: $lastError',
    );
  }

  Future<List<String>> _dbPathCandidates() async {
    if (!isSqfliteDesktopPlatform) {
      final base = await getDatabasesPath();
      final dir = Directory(base);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return [p.join(base, 'credit_calc_offline.db')];
    }

    final dirs = <Directory>[];
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      dirs.add(Directory(p.join(appData, 'CreditCalc', 'databases')));
    }
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      dirs.add(Directory(p.join(localAppData, 'CreditCalc', 'databases')));
    }
    try {
      final supportDir = await getApplicationSupportDirectory();
      dirs.add(Directory(p.join(supportDir.path, 'databases')));
    } catch (e) {
      debugPrint('LocalDatabaseService: getApplicationSupportDirectory: $e');
    }

    final paths = <String>[];
    for (final dir in dirs) {
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final testFile = File(p.join(dir.path, '.write_test'));
        await testFile.writeAsString('ok', flush: true);
        await testFile.delete();
        paths.add(p.join(dir.path, 'credit_calc_offline.db'));
      } catch (e) {
        debugPrint(
          'LocalDatabaseService: cartella non scrivibile ${dir.path}: $e',
        );
      }
    }
    return paths;
  }

  Future<void> upsertRecord({
    required String collection,
    required String id,
    required String userId,
    required Map<String, dynamic> payload,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? serverUpdatedAt,
    required SyncRecordStatus syncStatus,
    required String origin,
  }) async {
    final db = await database;
    await db.insert(
      'local_records',
      {
        'id': id,
        'collection': collection,
        'user_id': userId,
        'payload': await _encodePayload(payload),
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'server_updated_at': serverUpdatedAt?.millisecondsSinceEpoch,
        'sync_status': syncStatus.storageValue,
        'origin': origin,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> countRecordsForUser(String userId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM local_records WHERE user_id = ?',
      [userId],
    );
    final raw = rows.first['c'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  Future<int> maxUpdatedAtMsForUser(String userId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT MAX(updated_at) AS m FROM local_records WHERE user_id = ?',
      [userId],
    );
    final raw = rows.first['m'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  Future<int> countChangesSince(String userId, int sinceMs) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM local_records WHERE user_id = ? AND updated_at > ?',
      [userId, sinceMs],
    );
    final raw = rows.first['c'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  static String recordVersionKey(String collection, String id) =>
      '$collection::$id';

  /// Indice compatto per confronto tra dispositivi (collection::id → updatedAtMs).
  Future<({Map<String, int> versions, bool truncated})>
      recordVersionIndexForUser(
    String userId, {
    int maxEntries = 2000,
  }) async {
    final db = await database;
    final rows = await db.query(
      'local_records',
      columns: ['collection', 'id', 'updated_at'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    );
    final versions = <String, int>{};
    var truncated = false;
    for (final row in rows) {
      if (versions.length >= maxEntries) {
        truncated = true;
        break;
      }
      final collection = row['collection'] as String?;
      final id = row['id'] as String?;
      final updatedAt = row['updated_at'];
      if (collection == null || id == null || updatedAt is! int) continue;
      versions[recordVersionKey(collection, id)] = updatedAt;
    }
    return (versions: versions, truncated: truncated);
  }

  static int countRecordsNewerThanPeer(
    Map<String, int> localVersions,
    Map<String, int> peerVersions,
  ) {
    var count = 0;
    for (final entry in localVersions.entries) {
      final peerMs = peerVersions[entry.key];
      if (peerMs == null || entry.value > peerMs) count++;
    }
    return count;
  }

  static List<Map<String, dynamic>> mergeRecordLists(
    List<Map<String, dynamic>> primary,
    List<Map<String, dynamic>> secondary,
  ) {
    final byKey = <String, Map<String, dynamic>>{};
    for (final record in [...primary, ...secondary]) {
      final collection = record['collection'] as String?;
      final id = record['id'] as String?;
      if (collection == null || id == null) continue;
      byKey[recordVersionKey(collection, id)] = record;
    }
    final out = byKey.values.toList();
    out.sort((a, b) {
      final am = (a['updatedAt'] as DateTime).millisecondsSinceEpoch;
      final bm = (b['updatedAt'] as DateTime).millisecondsSinceEpoch;
      return am.compareTo(bm);
    });
    return out;
  }

  /// Record da inviare: modifiche locali dall'ultimo allineamento + delta
  /// rispetto all'indice versioni del peer (se disponibile).
  Future<List<Map<String, dynamic>>> recordsPendingSync(
    String userId, {
    required int sinceMs,
    Map<String, int>? peerVersions,
  }) async {
    final changed = await recordsChangedSince(userId, sinceMs);
    if (peerVersions == null) return changed;
    final missingOnPeer = await recordsMissingOnPeer(userId, peerVersions);
    return mergeRecordLists(changed, missingOnPeer);
  }

  Future<int> countRecordsMissingOnPeer(
    String userId,
    Map<String, int> peerVersions,
  ) async {
    final index = await recordVersionIndexForUser(userId);
    return countRecordsNewerThanPeer(index.versions, peerVersions);
  }

  Future<List<Map<String, dynamic>>> recordsMissingOnPeer(
    String userId,
    Map<String, int> peerVersions,
  ) async {
    final all = await listAllRecordsForUser(userId);
    final out = <Map<String, dynamic>>[];
    for (final record in all) {
      final collection = record['collection'] as String?;
      final id = record['id'] as String?;
      final updatedAt = record['updatedAt'] as DateTime?;
      if (collection == null || id == null || updatedAt == null) continue;
      final key = recordVersionKey(collection, id);
      final peerMs = peerVersions[key];
      final localMs = updatedAt.millisecondsSinceEpoch;
      if (peerMs == null || localMs > peerMs) {
        out.add(record);
      }
    }
    out.sort((a, b) {
      final am = (a['updatedAt'] as DateTime).millisecondsSinceEpoch;
      final bm = (b['updatedAt'] as DateTime).millisecondsSinceEpoch;
      return am.compareTo(bm);
    });
    return out;
  }

  Future<List<Map<String, dynamic>>> recordsChangedSince(
    String userId,
    int sinceMs,
  ) async {
    final db = await database;
    final rows = await db.query(
      'local_records',
      where: 'user_id = ? AND updated_at > ?',
      whereArgs: [userId, sinceMs],
      orderBy: 'updated_at ASC',
    );
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final record = await _tryRowToRecord(row);
      if (record != null) out.add(record);
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> listAllRecordsForUser(String userId) async {
    final db = await database;
    final rows = await db.query(
      'local_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final record = await _tryRowToRecord(row);
      if (record != null) out.add(record);
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> recordsForUser({
    required String userId,
    required String collection,
  }) async {
    final db = await database;
    final rows = await db.query(
      'local_records',
      where: 'user_id = ? AND collection = ?',
      whereArgs: [userId, collection],
      orderBy: 'created_at ASC',
    );
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final record = await _tryRowToRecord(row);
      if (record != null) out.add(record);
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> pendingRecords(String userId) async {
    final db = await database;
    final rows = await db.query(
      'local_records',
      where: 'user_id = ? AND sync_status = ?',
      whereArgs: [userId, SyncRecordStatus.pending.storageValue],
    );
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final record = await _tryRowToRecord(row);
      if (record != null) out.add(record);
    }
    return out;
  }

  Future<Map<String, dynamic>?> recordById({
    required String collection,
    required String id,
  }) async {
    final db = await database;
    final rows = await db.query(
      'local_records',
      where: 'collection = ? AND id = ?',
      whereArgs: [collection, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _tryRowToRecord(rows.first);
  }

  Future<void> deleteRecord({
    required String collection,
    required String id,
  }) async {
    final db = await database;
    await db.delete(
      'local_records',
      where: 'collection = ? AND id = ?',
      whereArgs: [collection, id],
    );
  }

  Future<void> markSynced({
    required String collection,
    required String id,
    required DateTime serverUpdatedAt,
  }) async {
    final db = await database;
    await db.update(
      'local_records',
      {
        'sync_status': SyncRecordStatus.synced.storageValue,
        'server_updated_at': serverUpdatedAt.millisecondsSinceEpoch,
      },
      where: 'collection = ? AND id = ?',
      whereArgs: [collection, id],
    );
  }

  Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> clearUserData(String userId) async {
    final db = await database;
    await db.delete(
      'local_records',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<Map<String, String>> listAllMeta() async {
    final db = await database;
    final rows = await db.query('app_meta');
    return {
      for (final row in rows)
        row['key']! as String: row['value']! as String,
    };
  }

  Future<void> clearAppMeta({Iterable<String>? exceptKeys}) async {
    final db = await database;
    final keep = exceptKeys?.toSet() ?? const {};
    if (keep.isEmpty) {
      await db.delete('app_meta');
      return;
    }
    final rows = await db.query('app_meta');
    final batch = db.batch();
    for (final row in rows) {
      final key = row['key']! as String;
      if (!keep.contains(key)) {
        batch.delete('app_meta', where: 'key = ?', whereArgs: [key]);
      }
    }
    await batch.commit(noResult: true);
  }

  /// Import bulk per trasferimento dispositivo (sostituzione totale).
  Future<void> importTransferRecords({
    required String userId,
    required List<Map<String, dynamic>> records,
  }) async {
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      final payload = record['payload'];
      if (payload is! Map<String, dynamic>) continue;
      final encoded = await _encodePayload(payload);
      batch.insert(
        'local_records',
        {
          'id': record['id'],
          'collection': record['collection'],
          'user_id': userId,
          'payload': encoded,
          'created_at': record['createdAtMs'],
          'updated_at': record['updatedAtMs'],
          'server_updated_at': record['serverUpdatedAtMs'],
          'sync_status': record['syncStatus'] ?? SyncRecordStatus.synced.storageValue,
          'origin': record['origin'] ?? 'device_transfer',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Unisce record in arrivo (delta): last-write-wins su updated_at.
  Future<int> mergeTransferRecords({
    required String userId,
    required List<Map<String, dynamic>> records,
  }) async {
    var applied = 0;
    final db = await database;
    for (final record in records) {
      final collection = record['collection'] as String?;
      final id = record['id'] as String?;
      final payload = record['payload'];
      if (collection == null || id == null || payload is! Map<String, dynamic>) {
        continue;
      }

      final incomingMs = record['updatedAtMs'] as int? ?? 0;
      final local = await recordById(collection: collection, id: id);
      if (local != null) {
        final localMs = (local['updatedAt'] as DateTime).millisecondsSinceEpoch;
        if (incomingMs < localMs) continue;
      }

      if (payload['_deleted'] == true) {
        final tombstonePayload = local != null
            ? (Map<String, dynamic>.from(local['payload'] as Map)
              ..['_deleted'] = true)
            : Map<String, dynamic>.from(payload);
        final encoded = await _encodePayload(tombstonePayload);
        final createdAtMs = record['createdAtMs'] as int?;
        final localCreatedMs = local != null
            ? (local['createdAt'] as DateTime).millisecondsSinceEpoch
            : null;
        await db.insert(
          'local_records',
          {
            'id': id,
            'collection': collection,
            'user_id': userId,
            'payload': encoded,
            'created_at': createdAtMs ?? localCreatedMs ?? incomingMs,
            'updated_at': incomingMs,
            'server_updated_at': record['serverUpdatedAtMs'],
            'sync_status':
                record['syncStatus'] ?? SyncRecordStatus.synced.storageValue,
            'origin': record['origin'] ?? 'device_transfer',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        applied++;
        continue;
      }

      final encoded = await _encodePayload(payload);
      final createdAtMs = record['createdAtMs'] as int?;
      final localCreatedMs = local != null
          ? (local['createdAt'] as DateTime).millisecondsSinceEpoch
          : null;
      await db.insert(
        'local_records',
        {
          'id': id,
          'collection': collection,
          'user_id': userId,
          'payload': encoded,
          'created_at': createdAtMs ?? localCreatedMs ?? incomingMs,
          'updated_at': incomingMs,
          'server_updated_at': record['serverUpdatedAtMs'],
          'sync_status':
              record['syncStatus'] ?? SyncRecordStatus.synced.storageValue,
          'origin': record['origin'] ?? 'device_transfer',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      applied++;
    }
    return applied;
  }

  /// True se esistono payload cifrati (v1) nel database locale.
  Future<bool> hasEncryptedPayloads() async {
    final db = await database;
    final rows = await db.query('local_records', limit: 32);
    for (final row in rows) {
      final raw = row['payload'] as String?;
      if (raw == null || raw.isEmpty) continue;
      if (raw.contains('"v":1') && raw.contains('"data"')) return true;
    }
    return false;
  }

  Future<String> _encodePayload(Map<String, dynamic> payload) async {
    final safe = FirestoreJsonCodec.encodeMap(payload);
    return LocalDataCipher.encryptJson(jsonEncode(safe));
  }

  static bool _looksLikeCipherEnvelope(Map<String, dynamic> map) =>
      map.containsKey('v') &&
      map.containsKey('iv') &&
      map.containsKey('data') &&
      !map.containsKey('userId') &&
      !map.containsKey('companyName') &&
      !map.containsKey('title');

  Future<Map<String, dynamic>> _decodePayload(String raw) async {
    try {
      final decoded = await _decodePayloadOnce(raw);
      if (_looksLikeCipherEnvelope(decoded)) {
        throw const FormatException('Payload itinerario ancora cifrato');
      }
      return decoded;
    } catch (e) {
      throw StateError('Decodifica payload locale fallita: $e');
    }
  }

  Future<Map<String, dynamic>?> _tryRowToRecord(Map<String, Object?> row) async {
    try {
      final payload = await _decodePayload(row['payload']! as String);
      return {
        'id': row['id'],
        'collection': row['collection'],
        'userId': row['user_id'],
        'payload': payload,
        'createdAt':
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        'updatedAt':
            DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
        'serverUpdatedAt': row['server_updated_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['server_updated_at']! as int,
              ),
        'syncStatus':
            SyncRecordStatusCodec.fromStorage(row['sync_status'] as String?),
        'origin': row['origin'],
      };
    } catch (e, st) {
      debugPrint(
        'LocalDatabaseService: salto record '
        '${row['collection']}/${row['id']}: $e\n$st',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>> _decodePayloadOnce(String raw) async {
    final asMap = jsonDecode(raw);
    if (asMap is! Map<String, dynamic>) {
      throw const FormatException('Payload non è un oggetto JSON');
    }

    if (asMap.containsKey('v') && asMap.containsKey('data')) {
      final plain = await LocalDataCipher.decryptJson(raw);
      final decoded = jsonDecode(plain);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Payload decifrato non valido');
      }
      return FirestoreJsonCodec.decodeMap(decoded);
    }

    return FirestoreJsonCodec.decodeMap(asMap);
  }
}
