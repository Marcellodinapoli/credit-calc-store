import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_card_theme.dart';
import '../core/theme/project_colors.dart';
import '../subscription/subscription_plan_options.dart';
import '../subscription/user_subscription_service.dart';
import '../subscription/user_subscription_snapshot.dart';

/// Contenuto gestione piano/abbonamento (host Planet o CreditCalc Store).
class SubscriptionAccountBody extends StatefulWidget {
  const SubscriptionAccountBody({super.key});

  @override
  State<SubscriptionAccountBody> createState() =>
      _SubscriptionAccountBodyState();
}

class _SubscriptionAccountBodyState extends State<SubscriptionAccountBody> {
  bool _busy = false;

  Future<void> _runAction(
    Future<void> Function() action, {
    String successMessage = 'Piano aggiornato.',
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _onChangePlan(
    UserSubscriptionSnapshot snapshot,
    SubscriptionPlanOption plan,
  ) async {
    if (plan.id == snapshot.planId) return;

    final isUpgrade =
        subscriptionPlanTier(plan.id) > subscriptionPlanTier(snapshot.planId);
    final action = isUpgrade ? 'upgrade' : 'cambio piano';

    if (!plan.availableNow && plan.id != 'free') {
      final proceed = await _confirm(
        title: 'Piano ${plan.name}',
        message:
            'Il piano ${plan.name} (${plan.price}) sarà attivabile con '
            'abbonamento a breve.\n\nPuoi comunque richiedere il $action: '
            'l\'attivazione effettiva avverrà quando il servizio sarà '
            'disponibile.',
        confirmLabel: 'Richiedi',
      );
      if (!proceed) return;
    } else {
      final proceed = await _confirm(
        title: isUpgrade ? 'Upgrade a ${plan.name}' : 'Passa a ${plan.name}',
        message: plan.id == 'free'
            ? 'Passerai al piano gratuito. L\'abbonamento a pagamento '
                'verrà disattivato.'
            : 'Confermi il $action verso ${plan.name} (${plan.price})?',
        confirmLabel: 'Conferma',
      );
      if (!proceed) return;
    }

    await _runAction(() => UserSubscriptionService.changePlan(plan.id));
  }

  Future<void> _onCancel(UserSubscriptionSnapshot snapshot) async {
    final proceed = await _confirm(
      title: 'Annulla abbonamento',
      message:
          'Confermi l\'annullamento dell\'abbonamento al piano '
          '${subscriptionPlanLabel(snapshot.planId)}?\n\n'
          'Il piano resterà indicato fino alla scadenza del periodo in '
          'corso; non verranno effettuati nuovi addebiti.',
      confirmLabel: 'Annulla abbonamento',
    );
    if (!proceed) return;

    await _runAction(
      UserSubscriptionService.cancelSubscription,
      successMessage: 'Abbonamento annullato.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserSubscriptionSnapshot>(
      stream: UserSubscriptionService.watchCurrent(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sub = snapshot.data!;
        final plans = subscriptionPlansForType(sub.registerType);
        final current = sub.planOption(plans);

        return AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Il tuo piano',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sub.canManage
                    ? 'Visualizza il piano attivo, le opzioni disponibili e '
                        'gestisci upgrade o annullamento abbonamento.'
                    : 'Piano associato al tuo account aziendale (sola lettura).',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              _CurrentPlanCard(
                snapshot: sub,
                plan: current,
              ),
              if (sub.hasCoupon || sub.lifetimeAccess) ...[
                const SizedBox(height: 12),
                _CouponInfoCard(snapshot: sub),
              ],
              if (sub.canCancel) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _onCancel(sub),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Annulla abbonamento'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text(
                'Tutti i piani',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Confronta le caratteristiche e richiedi un upgrade quando ti serve.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < plans.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _PlanCard(
                  plan: plans[i],
                  currentPlanId: sub.planId,
                  isCurrent: plans[i].id == sub.planId,
                  canChange: sub.canChangePlan,
                  onSelect: sub.canChangePlan
                      ? () => _onChangePlan(sub, plans[i])
                      : null,
                ),
              ],
              if (sub.lifetimeAccess) ...[
                const SizedBox(height: 16),
                Text(
                  'Hai accesso lifetime tramite coupon: per modifiche al piano '
                  'contatta assistenza@creditcore.it.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.snapshot,
    required this.plan,
  });

  final UserSubscriptionSnapshot snapshot;
  final SubscriptionPlanOption? plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ProjectColors.area.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppCardTheme.radius),
        side: BorderSide(color: ProjectColors.area.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Piano attuale',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: ProjectColors.area,
                  ),
                ),
                const Spacer(),
                _StatusChip(label: snapshot.statusLabel),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              plan?.name ?? subscriptionPlanLabel(snapshot.planId),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (plan != null) ...[
              const SizedBox(height: 4),
              Text(
                plan!.price,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: ProjectColors.area,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                plan!.description,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
            ],
            if (snapshot.cancelledAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Annullato il ${_formatDate(snapshot.cancelledAt!)}',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

class _CouponInfoCard extends StatelessWidget {
  const _CouponInfoCard({required this.snapshot});

  final UserSubscriptionSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF0FDF4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppCardTheme.radius),
        side: const BorderSide(color: Color(0xFF86EFAC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_outlined, color: Colors.green.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coupon applicato',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  if (snapshot.hasCoupon) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Codice: ${snapshot.couponCode}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    snapshot.lifetimeAccess
                        ? 'Accesso lifetime attivo: il piano selezionato è '
                            'attivo senza abbonamento ricorrente.'
                        : 'Coupon registrato in fase di iscrizione.',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.currentPlanId,
    required this.isCurrent,
    required this.canChange,
    this.onSelect,
  });

  final SubscriptionPlanOption plan;
  final String currentPlanId;
  final bool isCurrent;
  final bool canChange;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final tierLabel = switch (plan.id) {
      'enterprise' => 'ENTERPRISE',
      'plus' => 'PLUS',
      _ => 'FREE',
    };

    return Card(
      color: isCurrent ? Colors.white : AppCardTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppCardTheme.radius),
        side: BorderSide(
          color: isCurrent ? ProjectColors.area : const Color(0xFFE5E7EB),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tierLabel,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.04,
                  ),
                ),
                const Spacer(),
                Text(
                  plan.price,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: ProjectColors.area,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              plan.name,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              plan.description,
              style: TextStyle(
                color: Colors.grey.shade800,
                height: 1.45,
                fontSize: 13,
              ),
            ),
            if (!plan.availableNow && plan.id != 'free') ...[
              const SizedBox(height: 8),
              Text(
                'Abbonamento disponibile a breve',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (isCurrent) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: const Text('Piano attuale'),
                  backgroundColor:
                      ProjectColors.area.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: ProjectColors.area,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ] else if (canChange && onSelect != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: onSelect,
                  style: FilledButton.styleFrom(
                    backgroundColor: ProjectColors.area,
                  ),
                  child: Text(
                    subscriptionPlanTier(plan.id) >
                            subscriptionPlanTier(currentPlanId)
                        ? 'Upgrade'
                        : plan.id == 'free'
                            ? 'Passa a Gratis'
                            : 'Seleziona piano',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
