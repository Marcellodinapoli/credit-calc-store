import 'dart:async';
import 'dart:convert';

import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repository/credit_calc_repository.dart';

/// Contatori limiti CreditCalc sul dispositivo (senza sync Firebase).
class DevicePublicUsageLocalDataAccess implements PublicUsageLocalDataAccess {
  DevicePublicUsageLocalDataAccess(this._userId);

  final String _userId;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  String _prefsKey() => 'public_usage_local_v1_$_userId';

  static String _monthKey([DateTime? dt]) {
    final d = dt ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey());
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(), jsonEncode(data));
    notifyChanged();
  }

  Map<String, dynamic> _countsForMonth(Map<String, dynamic> data) {
    if (data['monthKey'] != _monthKey()) return {};
    final counts = data['counts'];
    if (counts is Map<String, dynamic>) return counts;
    if (counts is Map) return Map<String, dynamic>.from(counts);
    return {};
  }

  @override
  Future<int> readMonthlyCount(PublicUsageMetric metric) async {
    final field = publicUsageMonthlyStorageField(metric);
    if (field == null) return 0;
    final data = await _load();
    final counts = _countsForMonth(data);
    return _readInt(counts[field]);
  }

  @override
  Future<void> incrementMonthly(PublicUsageMetric metric, int amount) async {
    final field = publicUsageMonthlyStorageField(metric);
    if (field == null || amount <= 0) return;

    final data = await _load();
    final monthKey = _monthKey();
    var counts = _countsForMonth(data);
    if (data['monthKey'] != monthKey) counts = {};

    counts[field] = _readInt(counts[field]) + amount;
    await _save({
      'monthKey': monthKey,
      'counts': counts,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> resetMonthlyCounts() async {
    await _save({
      'monthKey': _monthKey(),
      'counts': <String, int>{},
      'resetAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<int> countCreditors(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final records = await CreditCalcRepository.instance.listCreditorRecords();
      return records.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<int> countCommissionSchemas(String userId) async {
    if (userId.isEmpty) return 0;
    try {
      final records = await CreditCalcRepository.instance.listCreditorRecords();
      var schemas = 0;
      for (final record in records) {
        final settings = record.data['commissionSettings'];
        if (settings is Map && settings.isNotEmpty) schemas++;
      }
      return schemas;
    } catch (_) {
      return 0;
    }
  }

  static int _readInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }
}
