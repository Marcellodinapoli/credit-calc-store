import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_card_theme.dart';
import '../widgets/public_page_shell.dart';
import '../widgets/public_top_menu.dart';
import 'login_pricing_page.dart';
import 'login_page.dart';
import 'public_detail_cards.dart';

/// Home pubblica leggera — intro breve prima di login/registrazione.
class PublicHomePage extends StatelessWidget {
  const PublicHomePage({super.key});

  static const _accent = Color(0xFF0A66C2);

  void _openLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = PublicPageShell.isMobile(context);

    return PublicPageShell(
      current: PublicPage.home,
      scrollable: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'CreditCore',
                style: PublicPageShell.pageTitleStyle().copyWith(fontSize: compact ? 30 : 36),
              ),
              const SizedBox(height: 12),
              const Text(
                'Formazione, strumenti operativi e opportunità professionali '
                'per chi lavora nel credito.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 28),
              const _EcosystemHighlights(),
              SizedBox(height: compact ? 32 : 40),
              FilledButton(
                onPressed: () => _openLogin(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Accedi o registrati'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginPricingPage(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Consulta piani e prezzi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EcosystemHighlights extends StatelessWidget {
  const _EcosystemHighlights();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CreditCoreEcosystemSection>>(
      stream: EcosystemSectionsConfigService.watchSections(),
      builder: (context, snapshot) {
        final sections =
            snapshot.data ?? EcosystemSectionsConfigService.sectionsForDisplay();

        return Column(
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _HighlightTile(section: sections[i]),
            ],
          ],
        );
      },
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.section});

  final CreditCoreEcosystemSection section;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppCardTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => showCreditCoreEcosystemSectionDetail(context, section),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Icon(section.icon, color: PublicHomePage._accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      section.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
