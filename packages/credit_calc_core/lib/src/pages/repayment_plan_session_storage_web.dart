// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

const _storageKey = 'credit_calc_repayment_plan_commission_doc_ids';

Future<void> preloadRepaymentPlanSessionStorage() async {}

List<String> readRepaymentPlanCommissionDocIds() {
  try {
    final raw = html.window.sessionStorage[_storageKey];
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .map((e) => e.toString())
        .where((id) => id.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
}

void appendRepaymentPlanCommissionDocIds(List<String> ids) {
  if (ids.isEmpty) return;
  final merged = readRepaymentPlanCommissionDocIds().toSet()..addAll(ids);
  html.window.sessionStorage[_storageKey] = jsonEncode(merged.toList());
}

void clearRepaymentPlanCommissionDocIds() {
  html.window.sessionStorage.remove(_storageKey);
}
