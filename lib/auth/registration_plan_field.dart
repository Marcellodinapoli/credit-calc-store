import 'package:flutter/material.dart';

import 'registration_plan_options.dart';

abstract final class _RegistrationPlanTheme {
  static const accent = Color(0xFF0A66C2);
}

/// Scelta piano (Gratis / Plus / Enterprise) nel form di registrazione.
class RegistrationPlanField extends StatelessWidget {
  final String registerType;
  final String? selectedPlanId;
  final ValueChanged<String> onPlanSelected;
  final String? errorText;

  const RegistrationPlanField({
    super.key,
    required this.registerType,
    required this.selectedPlanId,
    required this.onPlanSelected,
    this.errorText,
  });

  Future<void> _onPlanTap(
    BuildContext context,
    RegistrationPlanOption plan,
  ) async {
    if (!plan.availableNow) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Piano ${plan.name}'),
          content: Text(
            'Il piano ${plan.name} (${plan.price}) sarà attivabile con '
            'abbonamento a breve.\n\n'
            'Puoi comunque registrarti indicando questo piano: l\'attivazione '
            'effettiva avverrà quando il servizio sarà disponibile, oppure '
            'subito se applichi un coupon valido.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Indietro'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Seleziona'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    onPlanSelected(plan.id);
  }

  @override
  Widget build(BuildContext context) {
    final plans = registrationPlansForType(registerType);
    final isCompany = registerType == 'company';

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
          Text(
            isCompany ? 'Piano aziendale' : 'Piano',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Scegli Gratis, Plus o Enterprise.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < plans.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PlanTile(
              plan: plans[i],
              selected: selectedPlanId == plans[i].id,
              onTap: () => _onPlanTap(context, plans[i]),
            ),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final RegistrationPlanOption plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _RegistrationPlanTheme.accent.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _RegistrationPlanTheme.accent : const Color(0xFFE0E0E0),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: selected ? _RegistrationPlanTheme.accent : Colors.grey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          plan.price,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _RegistrationPlanTheme.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
