import 'package:flutter/material.dart';

import '../widgets/public_page_shell.dart';
import '../widgets/public_top_menu.dart';

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
                      title: 'Piani individuali',
                      subtitle: 'Per professionisti e utenti singoli',
                    ),
                    const SizedBox(height: 16),
                    const _PlanCard(
                      name: 'FREE',
                      price: '€0',
                      description:
                          'Uso base per testare la piattaforma.\n\n'
                          '3 corsi attivi · 10 quiz/mese · 5 Warm-up/mese · '
                          '2 Roleplay/mese · 3 contestazioni/mese · 1 piano di rientro '
                          '(simulazione) · 1 saldo/stralcio · 2 itinerari/mese · '
                          '5 creditori · 1 schema provvigioni · 3 candidature/mese.',
                    ),
                    const SizedBox(height: 16),
                    const _PlanCard(
                      name: 'PLUS',
                      price: '€4,99 / mese',
                      description:
                          'Uso personale completo con limiti medi-alti.\n\n'
                          'Fino a 50 corsi attivi · 200 quiz/mese · 100 Warm-up · '
                          '80 Roleplay · 50 contestazioni · 20 piani di rientro · '
                          '15 saldi/stralci · 20 itinerari · 200 creditori · '
                          'storico provvigioni completo · 50 candidature/mese.\n\n'
                          'Avviso al raggiungimento dell\'80% dei limiti.',
                      highlighted: true,
                      badge: 'Consigliato',
                    ),
                    const SizedBox(height: 16),
                    const _PlanCard(
                      name: 'ENTERPRISE',
                      price: '€9,99 / mese',
                      description:
                          'Uso intensivo quasi senza limiti operativi.\n\n'
                          'Corsi illimitati · Quiz illimitati · Warm-up illimitati · '
                          'Roleplay illimitati · Contestazioni illimitate · '
                          'Piani di rientro illimitati · Saldi e stralci illimitati · '
                          'Itinerari illimitati · Creditori illimitati · '
                          'Provvigioni illimitate · Candidature illimitate (fair use) · '
                          'Analytics provvigioni avanzate.',
                    ),
                    const SizedBox(height: 32),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 32),
                    const _SectionLabel(
                      title: 'Per aziende e team',
                      subtitle:
                          'Workspace dedicato con ruoli, recruiting e monitoraggio performance',
                    ),
                    const SizedBox(height: 16),
                    const _EnterprisePlanCard(
                      name: 'AZIENDA',
                      price: 'Prezzo su richiesta',
                      description:
                          'Soluzione completa per team e organizzazioni.\n\n'
                          'Workspace aziendale con gestione ruoli · '
                          'Pubblicazione offerte di lavoro · Gestione candidati · '
                          'Assegnazione attività · Dashboard dedicate ai supervisor · '
                          'Monitoraggio performance del team.',
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

  const _PlanCard({
    required this.name,
    required this.price,
    required this.description,
    this.highlighted = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
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
          const SizedBox(height: 12),
          _PlanDescriptionList(
            description: description,
            fontSize: 15,
          ),
        ],
      ),
    );
  }
}

class _EnterprisePlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String description;

  const _EnterprisePlanCard({
    required this.name,
    required this.price,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _PricingPageTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Soluzione per organizzazioni',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _PricingPageTheme.accent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _PlanDescriptionList(
            description: description,
            fontSize: 16,
          ),
        ],
      ),
    );
  }
}

class _PlanDescriptionList extends StatelessWidget {
  const _PlanDescriptionList({
    required this.description,
    required this.fontSize,
  });

  final String description;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: Colors.grey.shade800,
      height: 1.5,
      fontSize: fontSize,
    );
    final blocks = description
        .split('\n\n')
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildBlock(blocks[i], textStyle),
        ],
      ],
    );
  }

  Widget _buildBlock(String block, TextStyle textStyle) {
    if (!block.contains(' · ')) {
      return Text(block, style: textStyle);
    }

    final items = block
        .split(' · ')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < items.length - 1 ? 4 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: textStyle),
                Expanded(child: Text(items[i], style: textStyle)),
              ],
            ),
          ),
      ],
    );
  }
}
