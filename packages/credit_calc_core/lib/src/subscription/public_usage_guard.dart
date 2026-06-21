import 'package:flutter/material.dart';

import 'public_plan_limits.dart';
import 'public_usage_service.dart';

/// Verifica limite piano public e mostra messaggi UI.
abstract final class PublicUsageGuard {
  static Future<bool> ensureAllowed(
    BuildContext context,
    PublicUsageMetric metric, {
    int consumeAmount = 1,
    bool consumeOnSuccess = false,
  }) async {
    final result = await PublicUsageService.check(
      metric,
      consumeAmount: consumeAmount,
    );
    if (!context.mounted) return false;

    if (!result.allowed) {
      _showBlocked(context, result.message);
      return false;
    }

    if (result.warning && result.message != null) {
      _showWarning(context, result.message!);
    }

    if (consumeOnSuccess) {
      await PublicUsageService.consume(metric, amount: consumeAmount);
    }
    return true;
  }

  static Future<bool> checkAndConsume(
    BuildContext context,
    PublicUsageMetric metric, {
    int amount = 1,
  }) async {
    final ok = await ensureAllowed(
      context,
      metric,
      consumeAmount: amount,
    );
    if (!ok) return false;
    try {
      await PublicUsageService.consume(metric, amount: amount);
    } catch (_) {
      if (!context.mounted) return false;
      _showBlocked(
        context,
        'Impossibile registrare il consumo. Controlla la connessione e riprova.',
      );
      return false;
    }
    return true;
  }

  static Future<bool> ensureCourseAccess(
    BuildContext context,
    String courseId,
  ) async {
    final result = await PublicUsageService.checkCourseAccess(courseId);
    if (!context.mounted) return false;
    if (!result.allowed) {
      _showBlocked(context, result.message);
      return false;
    }
    if (result.warning && result.message != null) {
      _showWarning(context, result.message!);
    }
    return true;
  }

  static Future<bool> ensureCommissionHistoryAllowed(
    BuildContext context,
  ) async {
    final result = await PublicUsageService.checkCommissionHistoryAccess();
    if (!context.mounted) return false;
    if (!result.allowed) {
      _showBlocked(context, result.message);
      return false;
    }
    return true;
  }

  static Future<bool> ensureCommissionAnalyticsAllowed(
    BuildContext context,
  ) async {
    final result = await PublicUsageService.checkCommissionAnalyticsAccess();
    if (!context.mounted) return false;
    if (!result.allowed) {
      _showBlocked(context, result.message);
      return false;
    }
    return true;
  }

  static void _showBlocked(BuildContext context, String? message) {
    final text = message ??
        'Limite del piano raggiunto. Passa a un piano superiore per '
        'continuare.';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limite piano raggiunto'),
        content: Text(text),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
