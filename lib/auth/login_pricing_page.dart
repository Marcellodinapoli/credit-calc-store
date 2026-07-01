import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../widgets/public_page_shell.dart';
import '../widgets/public_top_menu.dart';
import 'plan_description_list.dart';
import 'public_detail_cards.dart';

abstract final class _PricingPageTheme {
  static const accent = Color(0xFF0A66C2);
}

/// Piani e prezzi CreditCore (allineato a CreditPlanet web /prezzi).
class LoginPricingPage extends StatelessWidget {
  const LoginPricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = PublicPageShell.isMobile(context);
    final horizontal = compact ? 16.0 : 24.0;

    return PublicPageShell(
      current: PublicPage.pricing,
      scrollable: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontal,
              compact ? 16.0 : 24.0,
              horizontal,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Piani e prezzi',
                      style: PublicPageShell.pageTitleStyle(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scegli il piano più adatto alle tue esigenze. Puoi iniziare '
                      'gratuitamente e passare a un piano superiore quando ti serve '
                      'più potenza e controllo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.45),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'I piani PLUS ed ENTERPRISE saranno attivabili con abbonamento. '
                      'Per le aziende è disponibile una soluzione dedicata su misura.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _SectionLabel(
                      title: 'Cosa include ogni piano',
                      subtitle:
                          'Tutti i piani danno accesso all\'ecosistema CreditCore; '
                          'i limiti indicano quante operazioni puoi svolgere.',
                    ),
                    const SizedBox(height: 16),
                    const EcosystemSectionsList(),
                    const SizedBox(height: 32),
                    const _SectionLabel(
                      title: 'Confronto piani',
                      subtitle: 'Prezzo, funzionalità e limiti operativi del piano attivo.',
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<Map<String, dynamic>?>(
                      stream: PublicPlanLimitsConfigService.watchPlansConfig(),
                      builder: (context, snapshot) {
                        final planOptions = PublicPlanLimitsConfigService
                            .subscriptionPlansForPublic();
                        return Column(
                          children: [
                            for (var i = 0; i < planOptions.length; i++) ...[
                              if (i > 0) const SizedBox(height: 16),
                              _PlanCard(
                                name: PublicPlanLimitsConfigService
                                    .publicPlanTierLabel(planOptions[i].id),
                                price: planOptions[i].price,
                                description: planOptions[i].description,
                                highlighted: planOptions[i].id == 'plus',
                                badge: planOptions[i].id == 'plus'
                                    ? 'Consigliato'
                                    : null,
                                limitsHeading: planOptions[i].id == 'enterprise'
                                    ? 'Cosa puoi fare'
                                    : 'Limiti operativi',
                                onTap: () => showSubscriptionPlanDetailCard(
                                  context,
                                  name: PublicPlanLimitsConfigService
                                      .publicPlanTierLabel(planOptions[i].id),
                                  price: planOptions[i].price,
                                  description: planOptions[i].description,
                                  badge: planOptions[i].id == 'plus'
                                      ? 'Consigliato'
                                      : null,
                                  limitsHeading: planOptions[i].id == 'enterprise'
                                      ? 'Cosa puoi fare'
                                      : 'Limiti operativi',
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionLabel({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
          ),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String description;
  final bool highlighted;
  final String? badge;
  final String? limitsHeading;
  final VoidCallback onTap;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.description,
    required this.onTap,
    this.highlighted = false,
    this.badge,
    this.limitsHeading,
  });

  @override
  Widget build(BuildContext context) {
    final intro = planDescriptionIntro(description);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted ? _PricingPageTheme.accent : Colors.grey.shade300,
              width: highlighted ? 2 : 1,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: _PricingPageTheme.accent.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _PricingPageTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _PricingPageTheme.accent,
                    ),
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              if (intro.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  intro,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Tocca per vedere ${limitsHeading?.toLowerCase() ?? 'i dettagli'}',
                style: const TextStyle(
                  color: _PricingPageTheme.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
