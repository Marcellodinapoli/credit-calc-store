import 'package:flutter/material.dart';

import 'public_plan_limits.dart';
import 'public_usage_local_data_access.dart';
import 'public_usage_service.dart';

/// Verifica limite piano public e mostra messaggi UI.
abstract final class PublicUsageGuard {
  static Future<bool> ensureAllowed(
    BuildContext context,
    PublicUsageMetric metric, {
    int consumeAmount = 1,
    bool consumeOnSuccess = false,
  }) async {
    try {
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
    } catch (_) {
      // Offline / errore rete: non bloccare operazioni CreditCalc sul dispositivo.
      if (PublicUsageLocalDataAccess.instance != null &&
          publicUsageMetricIsDeviceLocal(metric)) {
        return true;
      }
      if (context.mounted) {
        _showBlocked(
          context,
          'Impossibile verificare il piano. Controlla la connessione e riprova.',
        );
      }
      return false;
    }
  }

  static Future<bool> checkAndConsume(
    BuildContext context,
    PublicUsageMetric metric, {
    int amount = 1,
  }) async {
    try {
      final ok = await ensureAllowed(
        context,
        metric,
        consumeAmount: amount,
      );
      if (!ok) return false;
      await PublicUsageService.consume(metric, amount: amount);
      return true;
    } catch (_) {
      if (PublicUsageLocalDataAccess.instance != null &&
          publicUsageMetricIsDeviceLocal(metric)) {
        return true;
      }
      if (context.mounted) {
        _showBlocked(
          context,
          'Impossibile verificare il piano. Controlla la connessione e riprova.',
        );
      }
      return false;
    }
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
    try {
      final result = await PublicUsageService.checkCommissionHistoryAccess();
      if (!context.mounted) return false;
      if (!result.allowed) {
        _showBlocked(context, result.message);
        return false;
      }
      return true;
    } catch (_) {
      // Store offline: non bloccare inserimento/storico provvigioni locali.
      if (PublicUsageLocalDataAccess.instance != null) return true;
      if (context.mounted) {
        _showBlocked(
          context,
          'Impossibile verificare il piano. Controlla la connessione e riprova.',
        );
      }
      return false;
    }
  }

  static Future<bool> ensureCommissionAnalyticsAllowed(
    BuildContext context,
  ) async {
    try {
      final result = await PublicUsageService.checkCommissionAnalyticsAccess();
      if (!context.mounted) return false;
      if (!result.allowed) {
        _showBlocked(context, result.message);
        return false;
      }
      return true;
    } catch (_) {
      if (PublicUsageLocalDataAccess.instance != null) return true;
      if (context.mounted) {
        _showBlocked(
          context,
          'Impossibile verificare il piano. Controlla la connessione e riprova.',
        );
      }
      return false;
    }
  }

  static void _showBlocked(BuildContext context, String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ??
              'Limite del piano raggiunto. Passa a un piano superiore per '
              'continuare.',
        ),
        duration: const Duration(seconds: 5),
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
