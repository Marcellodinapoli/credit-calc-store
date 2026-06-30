import 'package:flutter/material.dart';

import 'platform_admin.dart';
import 'public_plan_limits.dart';
import 'public_usage_guard.dart';
import 'public_usage_service.dart';

/// Registra un consumo su Firebase (`public_usage/monthly` o totali pubblicati).
abstract final class PublicUsageCounterRecorder {
  /// Controllo limiti + incremento contatore (con messaggi UI).
  static Future<bool> recordWithUi(
    BuildContext context,
    PublicUsageMetric metric, {
    int amount = 1,
  }) =>
      PublicUsageGuard.checkAndConsume(context, metric, amount: amount);

  /// Controllo limiti + incremento senza UI.
  static Future<PublicUsageCheckResult> record(
    PublicUsageMetric metric, {
    int amount = 1,
  }) async {
    if (await PlatformAdmin.isCurrentUser()) {
      return PublicUsageCheckResult.skipped;
    }
    final result = await PublicUsageService.check(
      metric,
      consumeAmount: amount,
    );
    if (!result.allowed) return result;
    await PublicUsageService.consume(metric, amount: amount);
    return result;
  }

  static void showLimitMessage(
    BuildContext context,
    PublicUsageCheckResult result,
  ) {
    if (!context.mounted || result.allowed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ??
              'Limite del piano raggiunto. Passa a un piano superiore.',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
