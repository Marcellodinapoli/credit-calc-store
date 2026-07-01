import 'package:flutter/material.dart';

import 'plan_description_list.dart';
import 'public_detail_cards.dart';
import 'registration_coupon_field.dart';
import 'registration_coupon_service.dart';
import 'registration_plan_options.dart';
import 'registration_plan_selection_result.dart';

abstract final class _PlanPageTheme {
  static const accent = Color(0xFF0A66C2);
  static const body = Color(0xFFE8E8E8);
}

class RegistrationPlanSelectionPage extends StatefulWidget {
  final String registerType;

  const RegistrationPlanSelectionPage({
    super.key,
    required this.registerType,
  });

  @override
  State<RegistrationPlanSelectionPage> createState() =>
      _RegistrationPlanSelectionPageState();
}

class _RegistrationPlanSelectionPageState
    extends State<RegistrationPlanSelectionPage> {
  final _couponController = TextEditingController();
  RegistrationCouponValidation? _appliedCoupon;
  String? _couponError;
  bool _couponChecking = false;

  bool get _isCompany => widget.registerType == 'company';

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  List<RegistrationPlanOption> get _plans =>
      registrationPlansForType(widget.registerType);

  String get _title =>
      _isCompany ? 'Scegli il piano aziendale' : 'Scegli il tuo piano';

  String get _subtitle {
    if (_isCompany) {
      return 'Seleziona il piano da attivare per la tua azienda. '
          'Potrai completare la registrazione nel passo successivo.';
    }
    return 'Seleziona il piano da attivare per il tuo account utente. '
        'Potrai completare la registrazione nel passo successivo.';
  }

  bool _planAvailable(RegistrationPlanOption plan) {
    if (plan.availableNow) return true;
    return _appliedCoupon?.isValid == true;
  }

  Future<void> _applyCoupon() async {
    final raw = _couponController.text;
    if (raw.trim().isEmpty) {
      setState(() {
        _couponError = 'Inserisci un codice coupon.';
        _appliedCoupon = null;
      });
      return;
    }

    setState(() {
      _couponChecking = true;
      _couponError = null;
    });

    final result = await RegistrationCouponService.validate(raw);
    if (!mounted) return;

    setState(() {
      _couponChecking = false;
      if (!result.isValid) {
        _appliedCoupon = null;
        _couponError = 'Coupon non valido, scaduto o esaurito.';
        return;
      }
      _appliedCoupon = result;
      _couponError = null;
    });
  }

  void _clearCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponError = null;
      _couponController.clear();
    });
  }

  void _openPlanDetail(RegistrationPlanOption plan) {
    final available = _planAvailable(plan);
    final couponActive = _appliedCoupon?.isValid == true;
    final priceLabel = couponActive && !plan.availableNow
        ? 'Gratis per sempre'
        : plan.price;
    final actionLabel = available
        ? (couponActive && !plan.availableNow ? 'Attiva gratis' : 'Attiva ora')
        : 'Seleziona piano';

    showSubscriptionPlanDetailCard(
      context,
      name: plan.name,
      price: priceLabel,
      description: plan.description,
      badge: plan.id == 'plus' ? 'Consigliato' : null,
      limitsHeading: _isCompany ? 'Cosa include' : 'Limiti operativi',
      primaryActionLabel: actionLabel,
      onPrimaryAction: () => _onPlanTap(plan),
    );
  }

  Future<void> _onPlanTap(RegistrationPlanOption plan) async {
    if (!_planAvailable(plan)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Piano ${plan.name}'),
          content: Text(
            'Il piano ${plan.name} (${plan.price}) sarà attivabile con '
            'abbonamento a breve.\n\n'
            'Vuoi comunque registrarti indicando questo piano? '
            'L\'attivazione effettiva avverrà quando il servizio sarà disponibile.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Indietro'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continua'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final coupon = _appliedCoupon;
    if (coupon != null &&
        coupon.isValid &&
        coupon.restrictedPlan != null &&
        coupon.restrictedPlan != plan.id) {
      setState(() {
        _couponError =
            'Questo coupon è valido solo per il piano '
            '${registrationPlanLabel(coupon.restrictedPlan)}.';
      });
      return;
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      RegistrationPlanSelectionResult(
        planId: plan.id,
        couponCode: coupon?.isValid == true ? coupon!.code : null,
        couponApplied: coupon?.isValid == true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;
    final couponActive = _appliedCoupon?.isValid == true;

    return Scaffold(
      backgroundColor: _PlanPageTheme.body,
      appBar: AppBar(
        backgroundColor: _PlanPageTheme.body,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          _isCompany ? 'Registrazione azienda' : 'Registrazione utente',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111111),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      height: 1.45,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    couponActive
                        ? 'Coupon attivo: il piano scelto sarà gratuito per sempre.'
                        : 'I piani Plus ed Enterprise saranno attivabili con abbonamento. '
                            'Il piano Gratis è disponibile subito.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: couponActive
                          ? const Color(0xFF1B5E20)
                          : Colors.grey.shade600,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight:
                          couponActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CouponSection(
                    controller: _couponController,
                    checking: _couponChecking,
                    error: _couponError,
                    appliedCoupon: _appliedCoupon,
                    onApply: _applyCoupon,
                    onClear: _clearCoupon,
                  ),
                  const SizedBox(height: 24),
                  for (var i = 0; i < plans.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _PlanCard(
                      plan: plans[i],
                      highlighted: plans[i].id == 'plus',
                      available: _planAvailable(plans[i]),
                      couponActive: couponActive,
                      onTap: () => _openPlanDetail(plans[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CouponSection extends StatelessWidget {
  final TextEditingController controller;
  final bool checking;
  final String? error;
  final RegistrationCouponValidation? appliedCoupon;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _CouponSection({
    required this.controller,
    required this.checking,
    required this.error,
    required this.appliedCoupon,
    required this.onApply,
    required this.onClear,
  });

  bool get _applied => appliedCoupon?.isValid == true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
          if (_applied) ...[
            const SizedBox(height: 10),
            RegistrationCouponDetailsPanel(coupon: appliedCoupon!),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !_applied && !checking,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Codice coupon',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_applied)
                OutlinedButton(
                  onPressed: checking ? null : onClear,
                  child: const Text('Rimuovi'),
                )
              else
                FilledButton(
                  onPressed: checking ? null : onApply,
                  style: FilledButton.styleFrom(
                    backgroundColor: _PlanPageTheme.accent,
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

class _PlanCard extends StatelessWidget {
  final RegistrationPlanOption plan;
  final bool highlighted;
  final bool available;
  final bool couponActive;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.highlighted,
    required this.available,
    required this.couponActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = highlighted ? _PlanPageTheme.accent : Colors.grey.shade300;
    final priceLabel = couponActive && !plan.availableNow
        ? 'Gratis per sempre'
        : plan.price;
    final intro = planDescriptionIntro(plan.description);
    final actionLabel = available
        ? (couponActive && !plan.availableNow ? 'Attiva gratis' : 'Attiva ora')
        : 'Seleziona piano';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: highlighted ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    priceLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _PlanPageTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 20),
                ],
              ),
              if (intro.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  intro,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    color: _PlanPageTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
