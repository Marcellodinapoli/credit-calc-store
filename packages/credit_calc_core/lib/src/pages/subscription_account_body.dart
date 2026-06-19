import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_card_theme.dart';
import '../core/theme/project_colors.dart';
import '../subscription/subscription_billing_service.dart';
import '../subscription/company_collaborator_limit_service.dart';
import '../subscription/public_usage_service.dart';
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
    SubscriptionPlanOption plan, {
    required bool isCompany,
  }) async {
    if (!snapshot.canChangePlan) return;

    final currentId =
        isCompany ? normalizeCompanyPlanId(snapshot.planId) : snapshot.planId;
    if (plan.id == currentId) return;

    final isUpgrade = subscriptionPlanTierForAudience(
          plan.id,
          isCompany: isCompany,
        ) >
        subscriptionPlanTierForAudience(
          isCompany ? normalizeCompanyPlanId(snapshot.planId) : snapshot.planId,
          isCompany: isCompany,
        );

    if (SubscriptionBillingService.planUsesStripeCheckout(plan.id)) {
      final proceed = await _confirm(
        title: isUpgrade ? 'Upgrade a ${plan.name}' : 'Cambia piano',
        message:
            'Verrai reindirizzato alla pagina di pagamento Stripe per '
            'completare ${isUpgrade ? "l\'upgrade" : "il cambio"} verso '
            '${plan.name} (${plan.price}).\n\n'
            'Il piano si aggiornerà automaticamente al termine del pagamento.',
        confirmLabel: 'Vai al pagamento',
      );
      if (!proceed) return;

      await _runAction(
        () => SubscriptionBillingService.changePlan(
          audience: isCompany
              ? SubscriptionBillingAudience.company
              : SubscriptionBillingAudience.individual,
          planId: plan.id,
        ),
        successMessage: 'Pagamento Stripe avviato.',
      );
      return;
    }

    final proceed = await _confirm(
      title: 'Passa a ${plan.name}',
      message:
          'Passerai al piano gratuito. Se hai un abbonamento attivo, '
          'potrai gestirlo dal portale pagamenti Stripe.',
      confirmLabel: 'Conferma',
    );
    if (!proceed) return;

    await _runAction(
      () => SubscriptionBillingService.changePlan(
        audience: isCompany
            ? SubscriptionBillingAudience.company
            : SubscriptionBillingAudience.individual,
        planId: plan.id,
      ),
    );
  }

  Future<void> _onCancel(UserSubscriptionSnapshot snapshot) async {
    final proceed = await _confirm(
      title: 'Gestisci abbonamento',
      message:
          'Verrai reindirizzato al portale pagamenti Stripe per annullare '
          'o modificare l\'abbonamento al piano '
          '${subscriptionPlanLabel(snapshot.planId)}.\n\n'
          'Il piano resta attivo fino alla fine del periodo già pagato.',
      confirmLabel: 'Apri portale Stripe',
    );
    if (!proceed) return;

    await _runAction(
      UserSubscriptionService.cancelSubscription,
      successMessage: 'Portale pagamenti Stripe avviato.',
    );
  }

  bool _isSameCompanyPlan(String planId, String currentPlanId) {
    final normalized = switch (currentPlanId) {
      'azienda' => 'enterprise',
      'plus' => 'starter',
      _ => currentPlanId,
    };
    return planId == normalized;
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
        final isCompany = isCompanySubscriptionAudience(sub.registerType);

        if (isCompany) {
          final plans = companySubscriptionPlans();
          final current = companySubscriptionPlanForId(sub.planId);

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
                  'Scegli e cambia piano in autonomia: i piani a pagamento '
                  'si attivano tramite Stripe. Il piano gratuito si applica '
                  'subito in app.',
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
                StreamBuilder<CompanyCollaboratorUsage?>(
                  stream:
                      CompanyCollaboratorLimitService.watchCurrentCompanyUsage(),
                  builder: (context, usageSnap) {
                    final usage = usageSnap.data;
                    if (usage == null || !usage.atLimit) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _CollaboratorLimitReachedCard(
                        usage: usage,
                        canChangePlan: sub.canChangePlan,
                      ),
                    );
                  },
                ),
                if (sub.hasCoupon || sub.lifetimeAccess) ...[
                  const SizedBox(height: 12),
                  _CouponInfoCard(snapshot: sub),
                ],
                if (sub.canCancel) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _onCancel(sub),
                    icon: const Icon(Icons.payment_outlined),
                    label: const Text('Gestisci abbonamento su Stripe'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ProjectColors.area,
                      side: BorderSide(color: ProjectColors.area.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'Piani disponibili',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Offerta Fondatori: prezzo bloccato a vita. Seleziona un piano '
                  'e completa il pagamento su Stripe.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < plans.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _PlanCard(
                    plan: plans[i],
                    currentPlanId: normalizeCompanyPlanId(sub.planId),
                    isCurrent: _isSameCompanyPlan(plans[i].id, sub.planId),
                    canChange: sub.canChangePlan,
                    isCompanyAudience: true,
                    tierLabelOverride: plans[i].name,
                    onSelect: sub.canChangePlan &&
                            !_isSameCompanyPlan(plans[i].id, sub.planId)
                        ? () => _onChangePlan(sub, plans[i], isCompany: true)
                        : null,
                  ),
                ],
                const SizedBox(height: 28),
                StreamBuilder<CompanyCollaboratorUsage?>(
                  stream: CompanyCollaboratorLimitService
                      .watchCurrentCompanyUsage(),
                  builder: (context, usageSnap) {
                    if (usageSnap.connectionState == ConnectionState.waiting &&
                        !usageSnap.hasData) {
                      return const _MyConsumptionSection.loading();
                    }
                    final usage = usageSnap.data;
                    if (usage == null) return const SizedBox.shrink();
                    return _MyConsumptionSection(
                      items: [
                        PlanUsageItem(
                          label: 'Collaboratori attivi',
                          used: usage.active,
                          limit: usage.limit,
                        ),
                      ],
                    );
                  },
                ),
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
        }

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
                    ? 'Scegli e cambia piano in autonomia: i piani a pagamento '
                        'si attivano tramite Stripe. Il piano gratuito si '
                        'applica subito in app.'
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
                  icon: const Icon(Icons.payment_outlined),
                  label: const Text('Gestisci abbonamento su Stripe'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ProjectColors.area,
                    side: BorderSide(
                      color: ProjectColors.area.withValues(alpha: 0.5),
                    ),
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
                'Confronta i piani e completa upgrade o cambio tramite Stripe.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final sideBySide = constraints.maxWidth >= 640;
                  if (!sideBySide) {
                    return Column(
                      children: [
                        for (var i = 0; i < plans.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _PlanCard(
                            plan: plans[i],
                            currentPlanId: sub.planId,
                            isCurrent: plans[i].id == sub.planId,
                            canChange: sub.canChangePlan,
                            onSelect: sub.canChangePlan &&
                                    plans[i].id != sub.planId
                                ? () =>
                                    _onChangePlan(sub, plans[i], isCompany: false)
                                : null,
                          ),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < plans.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: _PlanCard(
                            plan: plans[i],
                            currentPlanId: sub.planId,
                            isCurrent: plans[i].id == sub.planId,
                            canChange: sub.canChangePlan,
                            onSelect: sub.canChangePlan &&
                                    plans[i].id != sub.planId
                                ? () => _onChangePlan(
                                      sub,
                                      plans[i],
                                      isCompany: false,
                                    )
                                : null,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              StreamBuilder<List<PlanUsageItem>>(
                stream: PublicUsageService.watchUsageItems(),
                builder: (context, usageSnap) {
                  if (usageSnap.connectionState == ConnectionState.waiting &&
                      !usageSnap.hasData) {
                    return const _MyConsumptionSection.loading();
                  }
                  final items = usageSnap.data;
                  if (items == null || items.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _MyConsumptionSection(items: items);
                },
              ),
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

class _MyConsumptionSection extends StatelessWidget {
  const _MyConsumptionSection({required this.items}) : loading = false;

  const _MyConsumptionSection.loading()
      : items = const [],
        loading = true;

  final List<PlanUsageItem> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I miei consumi',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Utilizzo rispetto ai limiti del piano attuale.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppCardTheme.radius),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(height: 18),
                        _UsageProgressRow(item: items[i]),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _UsageProgressRow extends StatelessWidget {
  const _UsageProgressRow({required this.item});

  final PlanUsageItem item;

  Color _barColor(double ratio) {
    if (ratio >= 0.9) return const Color(0xFFD32F2F);
    if (ratio >= 0.75) return const Color(0xFFE65100);
    if (ratio >= 0.55) return const Color(0xFFF9A825);
    return const Color(0xFF2E7D32);
  }

  @override
  Widget build(BuildContext context) {
    if (item.unlimited) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.all_inclusive, size: 20, color: ProjectColors.area),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (item.periodHint != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.periodHint!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final limit = item.limit!;
    final ratio = item.ratio ?? 0;
    final color = _barColor(ratio);
    final remaining = item.remaining ?? 0;
    final period = item.periodHint;

    String caption;
    if (remaining > 0) {
      caption = period == null
          ? '$remaining disponibili su $limit'
          : '$remaining disponibili su $limit $period';
    } else {
      caption = period == null
          ? 'Limite raggiunto ($limit)'
          : 'Limite raggiunto ($limit $period)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              '${item.used}/$limit',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                  ),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.75),
                          color,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _CollaboratorLimitReachedCard extends StatelessWidget {
  const _CollaboratorLimitReachedCard({
    required this.usage,
    required this.canChangePlan,
  });

  final CompanyCollaboratorUsage usage;
  final bool canChangePlan;

  String? _nextPlanLabel() {
    return switch (normalizeCompanyPlanId(usage.planId)) {
      'free' => 'Starter',
      'starter' => 'Business',
      'business' => 'Professional',
      'professional' => 'Enterprise',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final planLabel = subscriptionPlanLabel(usage.planId);
    final nextPlan = _nextPlanLabel();
    final atMaxTier = nextPlan == null;

    return Card(
      color: const Color(0xFFFFF7ED),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppCardTheme.radius),
        side: const BorderSide(color: Color(0xFFFDBA74)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.group_off_outlined, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limite collaboratori raggiunto',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stai usando tutti i ${usage.limit} posti collaboratori '
                    'previsti dal piano $planLabel '
                    '(${usage.active}/${usage.limit}).',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      height: 1.45,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    atMaxTier
                        ? 'Hai raggiunto il massimo previsto per il piano '
                            'Enterprise. Per esigenze superiori contatta '
                            'assistenza@creditcore.it.'
                        : canChangePlan
                            ? 'Per registrare nuovi collaboratori passa a un '
                                'piano superiore (es. $nextPlan): scegli un '
                                'upgrade tra i piani disponibili qui sotto.'
                            : 'Per registrare nuovi collaboratori è necessario '
                                'un upgrade del piano aziendale.',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      height: 1.45,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
    this.tierLabelOverride,
    this.actionLabel,
    this.isCompanyAudience = false,
  });

  final SubscriptionPlanOption plan;
  final String currentPlanId;
  final bool isCurrent;
  final bool canChange;
  final VoidCallback? onSelect;
  final String? tierLabelOverride;
  final String? actionLabel;
  final bool isCompanyAudience;

  @override
  Widget build(BuildContext context) {
    final tierLabel = tierLabelOverride ??
        switch (plan.id) {
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
          mainAxisSize: MainAxisSize.min,
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
            ] else if (SubscriptionBillingService.planUsesStripeCheckout(
              plan.id,
            )) ...[
              const SizedBox(height: 8),
              Text(
                'Pagamento sicuro con Stripe',
                style: TextStyle(
                  color: Colors.grey.shade600,
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
            ] else if (onSelect != null &&
                (canChange || actionLabel != null)) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: onSelect,
                  style: FilledButton.styleFrom(
                    backgroundColor: ProjectColors.area,
                  ),
                  child: Text(
                    actionLabel ??
                        _defaultActionLabel(
                          plan: plan,
                          currentPlanId: currentPlanId,
                          isCompanyAudience: isCompanyAudience,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _defaultActionLabel({
    required SubscriptionPlanOption plan,
    required String currentPlanId,
    required bool isCompanyAudience,
  }) {
    if (plan.id == 'free') return 'Passa a Gratis';
    if (SubscriptionBillingService.planUsesStripeCheckout(plan.id)) {
      return 'Vai al pagamento';
    }
    final isUpgrade = subscriptionPlanTierForAudience(
          plan.id,
          isCompany: isCompanyAudience,
        ) >
        subscriptionPlanTierForAudience(
          currentPlanId,
          isCompany: isCompanyAudience,
        );
    return isUpgrade ? 'Upgrade' : 'Seleziona piano';
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
