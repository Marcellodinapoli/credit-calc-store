import 'package:flutter/material.dart';

abstract final class _PricingPageTheme {
  static const accent = Color(0xFF0A66C2);
  static const body = Color(0xFFE8E8E8);
}

/// Piani e prezzi CreditCore (allineato a CreditPlanet web /prezzi).
class LoginPricingPage extends StatelessWidget {
  const LoginPricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PricingPageTheme.body,
      appBar: AppBar(
        backgroundColor: _PricingPageTheme.body,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Piani e prezzi'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                        'Accesso base alla piattaforma per uso personale. '
                        'Funzioni limitate per test e utilizzo occasionale, '
                        'senza strumenti avanzati né storico completo.',
                  ),
                  const SizedBox(height: 16),
                  const _PlanCard(
                    name: 'PLUS',
                    price: '€4,99 / mese',
                    description:
                        'Accesso completo alle funzionalità principali per uso '
                        'individuale. Include utilizzo illimitato dei servizi '
                        'core, storico delle attività e salvataggio dei dati. '
                        'Pensato per uso quotidiano con piena autonomia sulle '
                        'funzioni base.',
                    highlighted: true,
                    badge: 'Consigliato',
                  ),
                  const SizedBox(height: 16),
                  const _PlanCard(
                    name: 'ENTERPRISE',
                    price: '€9,99 / mese',
                    description:
                        'Piano avanzato per utenti professionali. Include tutte '
                        'le funzioni del PLUS con strumenti di analisi, '
                        'personalizzazione dei flussi, maggiore controllo sui dati '
                        'e priorità nelle prestazioni. Adatto a utilizzo intensivo '
                        'e scenari complessi.',
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
                        'Soluzione completa per team e organizzazioni. Workspace '
                        'aziendale con gestione ruoli (admin, supervisor, dipendenti), '
                        'pubblicazione offerte di lavoro, gestione candidati, '
                        'assegnazione attività e monitoraggio performance tramite '
                        'dashboard dedicate ai supervisor.',
                  ),
                ],
              ),
            ),
          ),
        ),
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
                  color: _PricingPageTheme.accent.withOpacity(0.12),
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
                color: _PricingPageTheme.accent.withOpacity(0.1),
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
          Text(
            description,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 15,
              height: 1.5,
            ),
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
              color: _PricingPageTheme.accent.withOpacity(0.12),
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
          Text(
            description,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
