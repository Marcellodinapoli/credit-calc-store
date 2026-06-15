import 'package:flutter/material.dart';

import 'registration_coupon_service.dart';
import 'registration_plan_selection_result.dart';

abstract final class _PlanPageTheme {
  static const accent = Color(0xFF0A66C2);
  static const body = Color(0xFFE8E8E8);
}

class RegistrationPlanOption {
  final String id;
  final String name;
  final String price;
  final String description;
  final bool availableNow;

  const RegistrationPlanOption({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    this.availableNow = true,
  });
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

  List<RegistrationPlanOption> get _plans {
    if (_isCompany) {
      return const [
        RegistrationPlanOption(
          id: 'free',
          name: 'Gratis',
          price: '€0',
          description:
              'Workspace aziendale base per iniziare. Funzioni essenziali '
              'con limiti su team, recruiting e strumenti avanzati.',
        ),
        RegistrationPlanOption(
          id: 'plus',
          name: 'Plus',
          price: '€4,99 / mese',
          description:
              'Workspace completo per piccoli team. Recruiting, gestione '
              'candidati e strumenti operativi con storico e salvataggio dati.',
          availableNow: false,
        ),
        RegistrationPlanOption(
          id: 'enterprise',
          name: 'Enterprise',
          price: '€9,99 / mese',
          description:
              'Soluzione avanzata per organizzazioni. Ruoli, supervisor, '
              'dashboard performance e priorità sulle funzioni aziendali.',
          availableNow: false,
        ),
      ];
    }

    return const [
      RegistrationPlanOption(
        id: 'free',
        name: 'Gratis',
        price: '€0',
        description:
            'Accesso base alla piattaforma per uso personale. Funzioni '
            'limitate per test e utilizzo occasionale.',
      ),
      RegistrationPlanOption(
        id: 'plus',
        name: 'Plus',
        price: '€4,99 / mese',
        description:
            'Accesso completo alle funzionalità principali. Utilizzo '
            'illimitato dei servizi core, storico attività e salvataggio dati.',
        availableNow: false,
      ),
      RegistrationPlanOption(
        id: 'enterprise',
        name: 'Enterprise',
        price: '€9,99 / mese',
        description:
            'Piano professionale con analisi, personalizzazione dei flussi '
            'e maggiore controllo sui dati per utilizzo intensivo.',
        availableNow: false,
      ),
    ];
  }

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
                    applied: couponActive,
                    appliedCode: _appliedCoupon?.code,
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
                      onTap: () => _onPlanTap(plans[i]),
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
  final bool applied;
  final String? appliedCode;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const _CouponSection({
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
            'Hai un codice promozionale? Inseriscilo per attivare l\'uso '
            'gratuito per sempre della piattaforma.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !applied && !checking,
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
              if (applied)
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
          if (applied && appliedCode != null) ...[
            const SizedBox(height: 8),
            Text(
              'Coupon $appliedCode applicato: accesso gratuito per sempre.',
              style: const TextStyle(
                color: Color(0xFF1B5E20),
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
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  available
                      ? (couponActive && !plan.availableNow
                          ? 'Attiva gratis'
                          : 'Attiva ora')
                      : 'Seleziona piano',
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
