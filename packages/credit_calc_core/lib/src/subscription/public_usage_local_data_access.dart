import 'dart:async';

import 'public_plan_limits.dart';

/// Contatori limiti piano sul dispositivo (dati operativi CreditCalc).
abstract class PublicUsageLocalDataAccess {
  static PublicUsageLocalDataAccess? instance;

  static void install(PublicUsageLocalDataAccess access) {
    instance = access;
  }

  static void clear() => instance = null;

  /// Notifica aggiornamento consumi locali (es. nuovo creditore).
  Stream<void> get changes;

  void notifyChanged();

  Future<int> readMonthlyCount(PublicUsageMetric metric);

  Future<void> incrementMonthly(PublicUsageMetric metric, int amount);

  Future<void> resetMonthlyCounts();

  Future<int> countCreditors(String userId);

  Future<int> countCommissionSchemas(String userId);
}
