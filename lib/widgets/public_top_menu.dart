import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/public_info_pages.dart';
import '../auth/login_page.dart';
import '../auth/login_pricing_page.dart';

/// Pagine pubbliche dell'app (senza landing).
enum PublicPage {
  login,
  about,
  contacts,
  faq,
  pricing,
}

/// Barra superiore con menu panino (mobile) o voci orizzontali (desktop).
class PublicTopBar extends StatelessWidget {
  final PublicPage current;

  const PublicTopBar({
    super.key,
    required this.current,
  });

  static const primaryBlue = Color(0xFF0A66C2);
  static const headerBorder = Color(0xFFE0E0E0);

  static void goLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _goLogin(BuildContext context) {
    if (current == PublicPage.login) return;
    goLogin(context);
  }

  void _openPage(BuildContext context, PublicPage page, Widget target) {
    if (current == page) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => target),
    );
  }

  Future<void> _openSitePath(BuildContext context, String path) async {
    final uri = Uri.parse('https://creditplanet.netlify.app$path');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire ${uri.host}')),
      );
    }
  }

  Widget _buildDesktopNav(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MenuItem(
          label: 'Accedi',
          active: current == PublicPage.login,
          onTap: current == PublicPage.login ? null : () => _goLogin(context),
        ),
        _MenuItem(
          label: 'Chi siamo',
          active: current == PublicPage.about,
          onTap: current == PublicPage.about
              ? null
              : () => _openPage(context, PublicPage.about, const PublicAboutPage()),
        ),
        _MenuItem(
          label: 'Contatti',
          active: current == PublicPage.contacts,
          onTap: current == PublicPage.contacts
              ? null
              : () => _openPage(
                    context,
                    PublicPage.contacts,
                    const PublicContactsPage(),
                  ),
        ),
        _MenuItem(
          label: 'FAQ',
          active: current == PublicPage.faq,
          onTap: current == PublicPage.faq
              ? null
              : () => _openPage(context, PublicPage.faq, const PublicFaqPage()),
        ),
        _MenuItem(
          label: 'Piani',
          active: current == PublicPage.pricing,
          onTap: current == PublicPage.pricing
              ? null
              : () => _openPage(
                    context,
                    PublicPage.pricing,
                    const LoginPricingPage(),
                  ),
        ),
      ],
    );
  }

  List<PopupMenuEntry<_PublicMobileMenuAction>> _mobileMenuItems() {
    return [
      CheckedPopupMenuItem<_PublicMobileMenuAction>(
        value: _PublicMobileMenuAction.login,
        checked: current == PublicPage.login,
        child: const Text('Accedi'),
      ),
      CheckedPopupMenuItem<_PublicMobileMenuAction>(
        value: _PublicMobileMenuAction.about,
        checked: current == PublicPage.about,
        child: Text('Chi siamo'),
      ),
      CheckedPopupMenuItem<_PublicMobileMenuAction>(
        value: _PublicMobileMenuAction.contacts,
        checked: current == PublicPage.contacts,
        child: Text('Contatti'),
      ),
      CheckedPopupMenuItem<_PublicMobileMenuAction>(
        value: _PublicMobileMenuAction.faq,
        checked: current == PublicPage.faq,
        child: Text('FAQ'),
      ),
      CheckedPopupMenuItem<_PublicMobileMenuAction>(
        value: _PublicMobileMenuAction.pricing,
        checked: current == PublicPage.pricing,
        child: Text('Piani'),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<_PublicMobileMenuAction>(
        value: _PublicMobileMenuAction.privacy,
        child: Text('Privacy'),
      ),
      const PopupMenuItem<_PublicMobileMenuAction>(
        value: _PublicMobileMenuAction.cookie,
        child: Text('Cookie Policy'),
      ),
      const PopupMenuItem<_PublicMobileMenuAction>(
        value: _PublicMobileMenuAction.terms,
        child: Text('Termini'),
      ),
    ];
  }

  void _onMobileMenuSelected(
    BuildContext context,
    _PublicMobileMenuAction value,
  ) {
    switch (value) {
      case _PublicMobileMenuAction.login:
        _goLogin(context);
        break;
      case _PublicMobileMenuAction.about:
        _openPage(context, PublicPage.about, const PublicAboutPage());
        break;
      case _PublicMobileMenuAction.contacts:
        _openPage(context, PublicPage.contacts, const PublicContactsPage());
        break;
      case _PublicMobileMenuAction.faq:
        _openPage(context, PublicPage.faq, const PublicFaqPage());
        break;
      case _PublicMobileMenuAction.pricing:
        _openPage(context, PublicPage.pricing, const LoginPricingPage());
        break;
      case _PublicMobileMenuAction.privacy:
        _openSitePath(context, '/privacy-policy');
        break;
      case _PublicMobileMenuAction.cookie:
        _openSitePath(context, '/cookie-policy');
        break;
      case _PublicMobileMenuAction.terms:
        _openSitePath(context, '/privacy-policy');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width <= 700;

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: PublicTopBar.headerBorder),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _goLogin(context),
                  child: const Text(
                    'CreditCore',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 16),
                  _buildDesktopNav(context),
                ],
                const Spacer(),
                if (isMobile)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MenuItem(
                        label: 'Accedi',
                        active: current == PublicPage.login,
                        onTap: current == PublicPage.login
                            ? null
                            : () => _goLogin(context),
                      ),
                      const SizedBox(width: 16),
                      PopupMenuButton<_PublicMobileMenuAction>(
                        tooltip: 'Menu',
                        position: PopupMenuPosition.under,
                        initialValue: switch (current) {
                          PublicPage.login => _PublicMobileMenuAction.login,
                          PublicPage.about => _PublicMobileMenuAction.about,
                          PublicPage.contacts => _PublicMobileMenuAction.contacts,
                          PublicPage.faq => _PublicMobileMenuAction.faq,
                          PublicPage.pricing => _PublicMobileMenuAction.pricing,
                        },
                        icon: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: Color(0xFF111111),
                            size: 20,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) =>
                            _onMobileMenuSelected(context, value),
                        itemBuilder: (context) => _mobileMenuItems(),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PublicMobileMenuAction {
  login,
  about,
  contacts,
  faq,
  pricing,
  privacy,
  cookie,
  terms,
}

class _MenuItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: active
                    ? const Color(0xFF111111)
                    : const Color(0xFF6B7280),
                height: 1.25,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: active ? 40 : 0,
            decoration: BoxDecoration(
              color: PublicTopBar.primaryBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
