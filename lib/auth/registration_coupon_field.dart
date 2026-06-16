import 'package:flutter/material.dart';

abstract final class _CouponFieldTheme {
  static const accent = Color(0xFF0A66C2);
}

/// Campo coupon nel form di registrazione (CreditCore store).
class RegistrationCouponSection extends StatelessWidget {
  final TextEditingController controller;
  final bool checking;
  final String? error;
  final bool applied;
  final String? appliedCode;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const RegistrationCouponSection({
    super.key,
    required this.controller,
    required this.checking,
    required this.error,
    required this.applied,
    required this.appliedCode,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
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
            'Codice promozionale per accesso gratuito per sempre.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
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
          if (applied && appliedCode != null) ...[
            const SizedBox(height: 8),
            Text(
              'Coupon $appliedCode applicato: accesso gratuito per sempre.',
              style: TextStyle(
                color: Colors.green.shade800,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
