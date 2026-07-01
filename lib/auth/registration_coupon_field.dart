import 'package:flutter/material.dart';

import 'registration_coupon_service.dart';
import 'registration_plan_selection_result.dart';

abstract final class _CouponFieldTheme {
  static const accent = Color(0xFF0A66C2);
}

String _formatCouponDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// Dettagli coupon dopo l'applicazione in registrazione.
class RegistrationCouponDetailsPanel extends StatelessWidget {
  final RegistrationCouponValidation coupon;

  const RegistrationCouponDetailsPanel({super.key, required this.coupon});

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (coupon.label != null && coupon.label!.isNotEmpty) coupon.label!,
      if (coupon.restrictedPlan != null)
        'Piano: ${registrationPlanLabel(coupon.restrictedPlan)}',
      if (coupon.lifetimeFree)
        'Accesso gratuito per sempre'
      else if (coupon.benefitExpiresAt != null)
        'Beneficio attivo fino al ${_formatCouponDate(coupon.benefitExpiresAt!)}',
    ];

    if (lines.isEmpty) {
      lines.add('Coupon ${coupon.code} applicato.');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coupon ${coupon.code}',
            style: TextStyle(
              color: Colors.green.shade900,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final line in lines) ...[
            Text(
              line,
              style: TextStyle(
                color: Colors.green.shade900,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Campo coupon nel form di registrazione (CreditCore store).
class RegistrationCouponSection extends StatelessWidget {
  final TextEditingController controller;
  final bool checking;
  final String? error;
  final bool applied;
  final RegistrationCouponValidation? appliedCoupon;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const RegistrationCouponSection({
    super.key,
    required this.controller,
    required this.checking,
    required this.error,
    required this.applied,
    this.appliedCoupon,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Coupon',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Se hai un codice promozionale inseriscilo.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          if (applied && appliedCoupon?.isValid == true) ...[
            const SizedBox(height: 10),
            RegistrationCouponDetailsPanel(coupon: appliedCoupon!),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !applied && !checking,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Codice coupon',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (applied)
                OutlinedButton(
                  onPressed: checking ? null : onClear,
                  child: const Text('Rimuovi'),
                )
              else
                FilledButton(
                  onPressed: checking ? null : onApply,
                  style: FilledButton.styleFrom(
                    backgroundColor: _CouponFieldTheme.accent,
                  ),
                  child: checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Applica'),
                ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
