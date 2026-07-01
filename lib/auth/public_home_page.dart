import 'package:flutter/material.dart';

import '../widgets/public_page_shell.dart';
import '../widgets/public_top_menu.dart';
import 'login_pricing_page.dart';
import 'login_page.dart';

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
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
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
              const _HighlightTile(
                icon: Icons.school_outlined,
                title: 'CreditForm',
                subtitle: 'Corsi, quiz e percorsi formativi',
              ),
              const SizedBox(height: 10),
              const _HighlightTile(
                icon: Icons.calculate_outlined,
                title: 'CreditCalc',
                subtitle: 'Simulazioni e strumenti per l\'operatività',
              ),
              const SizedBox(height: 10),
              const _HighlightTile(
                icon: Icons.work_outline,
                title: 'CreditJob',
                subtitle: 'Collegamenti tra aziende e professionisti',
              ),
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

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: PublicHomePage._accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
