import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/sync_record_status.dart';
import '../utils/firestore_json_codec.dart';
import 'local_data_cipher.dart';

/// Database SQLite locale per CreditCalc offline.
class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final path = await _dbPath();
    _db = await openDatabase(
      path,
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
    return _db!;
  }

  Future<String> _dbPath() async {
    final base = await getDatabasesPath();
    return p.join(base, 'credit_calc_offline.db');
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
      out.add(await _rowToRecord(row));
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
      out.add(await _rowToRecord(row));
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
    return _rowToRecord(rows.first);
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

  Future<String> _encodePayload(Map<String, dynamic> payload) async {
    final safe = FirestoreJsonCodec.encodeMap(payload);
    return LocalDataCipher.encryptJson(jsonEncode(safe));
  }

  Future<Map<String, dynamic>> _decodePayload(String raw) async {
    try {
      final asMap = jsonDecode(raw);
      if (asMap is Map<String, dynamic> &&
          asMap.containsKey('v') &&
          asMap.containsKey('data')) {
        final plain = await LocalDataCipher.decryptJson(raw);
        final decoded = jsonDecode(plain) as Map<String, dynamic>;
        return FirestoreJsonCodec.decodeMap(decoded);
      }
      if (asMap is Map<String, dynamic>) {
        return FirestoreJsonCodec.decodeMap(asMap);
      }
    } catch (_) {}
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return FirestoreJsonCodec.decodeMap(decoded);
  }

  Future<Map<String, dynamic>> _rowToRecord(Map<String, Object?> row) async {
    final payload = await _decodePayload(row['payload']! as String);
    return {
      'id': row['id'],
      'collection': row['collection'],
      'userId': row['user_id'],
      'payload': payload,
      'createdAt': DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      'updatedAt': DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
      'serverUpdatedAt': row['server_updated_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['server_updated_at']! as int),
      'syncStatus': SyncRecordStatusCodec.fromStorage(row['sync_status'] as String?),
      'origin': row['origin'],
    };
  }
}
