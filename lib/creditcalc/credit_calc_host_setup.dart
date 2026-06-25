import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../widgets/schedule_field_visit_dialog.dart';

/// Hook store-specifici per le pagine CreditCalc core.
abstract final class CreditCalcHostSetup {
  static void install() {
    RepaymentPlanHostConfig.offerFollowUpVisit = _offerFollowUpVisit;
    CommissionCollectionsHostConfig.scheduleFieldVisit = _scheduleFieldVisit;
    BackofficePendingPlanHostConfig.buildRepaymentPlanPage = _buildRepaymentPlan;
    BackofficePendingPlanHostConfig.buildBalanceWriteOffPage = _buildBalanceWriteOff;
  }

  static Widget _buildRepaymentPlan(BackofficePlanEditorRequest request) {
    return StandardRepaymentPlanPage(
      pendingPlanId: request.pendingPlanId,
      initialFormData: request.initialFormData,
      skipInitialUsageGuard: request.skipInitialUsageGuard,
      autoOpenCommissionExport: request.autoOpenCommissionExport,
      initialCommissionDocIds: request.initialCommissionDocIds,
      initialCompanyName: request.initialCompanyName,
    );
  }

  static Widget _buildBalanceWriteOff(BackofficePlanEditorRequest request) {
    return BalanceWriteOffPage(
      pendingPlanId: request.pendingPlanId,
      initialFormData: request.initialFormData,
      skipInitialUsageGuard: request.skipInitialUsageGuard,
      autoOpenCommissionExport: request.autoOpenCommissionExport,
      initialCommissionDocIds: request.initialCommissionDocIds,
      initialCompanyName: request.initialCompanyName,
    );
  }

  static Future<void> _scheduleFieldVisit(
    BuildContext context,
    CommissionCollectionVisitRequest request,
  ) async {
    await showScheduleFieldVisitDialog(
      context,
      calculation: request.entryData,
      calculationId: request.entryId,
      initialDay: request.initialDay,
    );
  }

  static Future<void> _offerFollowUpVisit(
    BuildContext context,
    RepaymentPlanFollowUpRequest request,
  ) async {
    final schedule = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Follow-up sul territorio'),
        content: const Text(
          'Vuoi programmare una visita in agenda per il follow-up '
          'dopo il piano di rientro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non ora'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Programma visita'),
          ),
        ],
      ),
    );

    if (schedule != true || !context.mounted) return;

    await showScheduleFieldVisitDialog(
      context,
      calculation: {
        'companyName': request.companyName,
        'creditorId': request.creditorId,
        'creditorName': request.creditorName,
      },
      calculationId: request.calculationId ?? '',
      initialDay: DateTime.now().add(const Duration(days: 7)),
    );
  }
}
