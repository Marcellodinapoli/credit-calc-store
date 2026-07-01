import 'package:flutter/material.dart';

import '../widgets/public_page_shell.dart';
import 'plan_description_list.dart';

abstract final class _DetailTheme {
  static const accent = Color(0xFF0A66C2);
}

class CreditCoreEcosystemSection {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> highlights;
  final String body;

  const CreditCoreEcosystemSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.highlights,
    required this.body,
  });
}

const creditCoreEcosystemSections = <CreditCoreEcosystemSection>[
  CreditCoreEcosystemSection(
    id: 'creditform',
    title: 'CreditForm',
    subtitle: 'Formazione digitale',
    icon: Icons.school_outlined,
    color: Color(0xFFFFA726),
    highlights: [
      'Corsi e video formativi',
      'Quiz e listening',
      'Warm-Up AI e Roleplay AI',
      'Training contestazioni',
    ],
    body:
        'Percorsi formativi strutturati con video, quiz, listening e role play '
        'per misurare i progressi e allenare le competenze operative nel credito.',
  ),
  CreditCoreEcosystemSection(
    id: 'creditcalc',
    title: 'CreditCalc',
    subtitle: 'Strumenti operativi',
    icon: Icons.calculate_outlined,
    color: Color(0xFF00B0FF),
    highlights: [
      'Creditori e anagrafiche',
      'Piani di rientro e saldo/stralcio',
      'Provvigioni e incassi',
      'Itinerario e agenda attività',
    ],
    body:
        'Simulazioni, calcoli e strumenti per gestire creditori, piani di rientro, '
        'provvigioni e attività sul territorio con dati salvati sul profilo.',
  ),
  CreditCoreEcosystemSection(
    id: 'creditjob',
    title: 'CreditJob',
    subtitle: 'Opportunità professionali',
    icon: Icons.work_outline,
    color: Color(0xFF00C4B3),
    highlights: [
      'Offerte di lavoro',
      'Candidature e salvataggio annunci',
      'Monitoraggio selezioni',
    ],
    body:
        'Collegamenti tra aziende e professionisti: ricerca offerte, candidature '
        'e monitoraggio dello stato delle selezioni in un unico ambiente.',
  ),
];

CreditCoreEcosystemSection? creditCoreEcosystemSectionForId(String id) {
  for (final section in creditCoreEcosystemSections) {
    if (section.id == id) return section;
  }
  return null;
}

Future<void> showCreditCoreEcosystemSectionDetail(
  BuildContext context,
  CreditCoreEcosystemSection section,
) {
  return _showPublicDetailCard(
    context,
    child: _EcosystemSectionDetailBody(section: section),
  );
}

Future<T?> showSubscriptionPlanDetailCard<T>(
  BuildContext context, {
  required String name,
  required String price,
  required String description,
  String? badge,
  String? limitsHeading,
  String? primaryActionLabel,
  VoidCallback? onPrimaryAction,
}) {
  return _showPublicDetailCard<T>(
    context,
    child: _SubscriptionPlanDetailBody(
      name: name,
      price: price,
      description: description,
      badge: badge,
      limitsHeading: limitsHeading,
      primaryActionLabel: primaryActionLabel,
      onPrimaryAction: onPrimaryAction,
    ),
  );
}

Future<T?> _showPublicDetailCard<T>(
  BuildContext context, {
  required Widget child,
}) {
  final compact = PublicPageShell.isMobile(context);

  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          expand: false,
          builder: (_, scrollController) => _DetailCardShell(
            scrollController: scrollController,
            child: child,
          ),
        ),
      ),
    );
  }

  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: _DetailCardShell(child: child),
      ),
    ),
  );
}

class EcosystemSectionCard extends StatelessWidget {
  const EcosystemSectionCard({
    super.key,
    required this.section,
    required this.onTap,
  });

  final CreditCoreEcosystemSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(section.icon, color: section.color, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                section.subtitle,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 10),
              for (final item in section.highlights.take(3)) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: Colors.grey.shade800)),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Tocca per i dettagli',
                style: TextStyle(
                  color: _DetailTheme.accent,
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

class _DetailCardShell extends StatelessWidget {
  const _DetailCardShell({
    required this.child,
    this.scrollController,
  });

  final Widget child;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: child,
      ),
    );
  }
}

class _EcosystemSectionDetailBody extends StatelessWidget {
  const _EcosystemSectionDetailBody({required this.section});

  final CreditCoreEcosystemSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailHeader(
          title: section.title,
          subtitle: section.subtitle,
          icon: section.icon,
          iconColor: section.color,
        ),
        const SizedBox(height: 14),
        Text(
          section.body,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Cosa include',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in section.highlights)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: Colors.grey.shade800)),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ),
      ],
    );
  }
}

class _SubscriptionPlanDetailBody extends StatelessWidget {
  const _SubscriptionPlanDetailBody({
    required this.name,
    required this.price,
    required this.description,
    this.badge,
    this.limitsHeading,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  final String name;
  final String price;
  final String description;
  final String? badge;
  final String? limitsHeading;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailHeader(title: name, subtitle: price),
        if (badge != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _DetailTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _DetailTheme.accent,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (limitsHeading != null) ...[
          Text(
            limitsHeading!,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
        ],
        PlanDescriptionList(description: description, fontSize: 15),
        const SizedBox(height: 20),
        if (primaryActionLabel != null && onPrimaryAction != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onPrimaryAction!();
            },
            style: FilledButton.styleFrom(
              backgroundColor: _DetailTheme.accent,
              minimumSize: const Size(double.infinity, 46),
            ),
            child: Text(primaryActionLabel!),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _DetailTheme.accent,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
