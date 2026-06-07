import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'credit_calc_repayment_plan_commission_doc_ids';

List<String> _cachedIds = [];
bool _loaded = false;

Future<void> preloadRepaymentPlanSessionStorage() async {
  if (_loaded) return;
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_storageKey);
  if (raw == null || raw.isEmpty) {
    _cachedIds = [];
  } else {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _cachedIds = decoded
            .map((e) => e.toString())
            .where((id) => id.isNotEmpty)
            .toList();
      }
    } catch (_) {
      _cachedIds = [];
    }
  }
  _loaded = true;
}

Future<void> _persistIds() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_storageKey, jsonEncode(_cachedIds));
}

List<String> readRepaymentPlanCommissionDocIds() => List.unmodifiable(_cachedIds);

void appendRepaymentPlanCommissionDocIds(List<String> ids) {
  if (ids.isEmpty) return;
  preloadRepaymentPlanSessionStorage().then((_) async {
    final merged = _cachedIds.toSet()..addAll(ids);
    _cachedIds = merged.toList();
    await _persistIds();
  });
}

void clearRepaymentPlanCommissionDocIds() {
  _cachedIds = [];
  SharedPreferences.getInstance().then((prefs) => prefs.remove(_storageKey));
}
