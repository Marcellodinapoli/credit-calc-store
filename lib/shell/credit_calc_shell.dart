import 'package:credit_calc_core/credit_calc_core.dart'
    hide CommissionsPage, CreditorsPage, DevelopPage;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/dimensions.dart';
import '../core/maintenance_service.dart';
import '../pages/creditcalc/commissions_page.dart';
import '../pages/creditcalc/creditors_page.dart';
import '../pages/creditcalc/develop_page.dart';
import '../ui/layout/page_shell.dart';
import '../widgets/maintenance_blocked_view.dart';
import 'credit_core_account_menu_sheet.dart';
import 'credit_core_site_actions.dart';

class CreditCalcShell extends StatefulWidget {
  const CreditCalcShell({super.key});

  @override
  State<CreditCalcShell> createState() => _CreditCalcShellState();
}

class _CreditCalcShellState extends State<CreditCalcShell> {
  CreditCalcNavItem _section = CreditCalcNavItem.creditors;

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esci'),
        content: const Text('Vuoi uscire dall\'account CreditCore?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Esci'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseAuth.instance.signOut();
    // AuthGate (home) reagisce ad authStateChanges e mostra di nuovo LoginPage.
  }

  void _showAccountMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CreditCoreAccountMenuSheet(
        onAnnouncements: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AnnouncementsPage(),
            ),
          );
        },
        onLogout: _logout,
      ),
    );
  }

  Widget _sectionPage(CreditCalcNavItem item) {
    switch (item) {
      case CreditCalcNavItem.creditors:
        return const CreditorsPage();
      case CreditCalcNavItem.develop:
        return const DevelopPage();
      case CreditCalcNavItem.commissions:
        return const CommissionsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = Dimensions.useCompactShell(context);

    return StreamBuilder(
      stream: MaintenanceService.watch(),
      builder: (context, maintenanceSnap) {
        final maintenanceData = MaintenanceService.dataFrom(maintenanceSnap.data);
        final calcBlocked = MaintenanceService.isSectionBlocked(
          maintenanceData,
          MaintenanceService.creditCalc,
        );

        if (calcBlocked) {
          return Scaffold(
            backgroundColor: PageShellTheme.scaffoldBackground,
            appBar: AppBar(
              backgroundColor: PageShellTheme.appBarBackground,
              title: const _BrandTitle(),
              actions: [
                const AnnouncementsBellButton(iconColor: Colors.black87),
                IconButton(
                  tooltip: 'Menu',
                  onPressed: _showAccountMenu,
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
            body: const MaintenanceBlockedView(
              sectionName: MaintenanceService.creditCalc,
            ),
          );
        }

        if (compact) {
          return _MobileShell(
            section: _section,
            onSectionChanged: (item) => setState(() => _section = item),
            onMenu: _showAccountMenu,
            child: _sectionPage(_section),
          );
        }

        return _DesktopShell(
          section: _section,
          onSectionChanged: (item) => setState(() => _section = item),
          onLogout: _logout,
          child: _sectionPage(_section),
        );
      },
    );
  }
}

class _MobileShell extends StatelessWidget {
  final CreditCalcNavItem section;
  final ValueChanged<CreditCalcNavItem> onSectionChanged;
  final VoidCallback onMenu;
  final Widget child;

  const _MobileShell({
    required this.section,
    required this.onSectionChanged,
    required this.onMenu,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PageShellTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: PageShellTheme.appBarBackground,
        title: const _BrandTitle(),
        actions: [
          const AnnouncementsBellButton(iconColor: Colors.black87),
          IconButton(
            tooltip: 'Menu',
            onPressed: onMenu,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: section.index,
        onDestinationSelected: (index) =>
            onSectionChanged(CreditCalcNavItem.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Creditori',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Sviluppa',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Provvigioni',
          ),
        ],
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  final CreditCalcNavItem section;
  final ValueChanged<CreditCalcNavItem> onSectionChanged;
  final Future<void> Function() onLogout;
  final Widget child;

  const _DesktopShell({
    required this.section,
    required this.onSectionChanged,
    required this.onLogout,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PageShellTheme.scaffoldBackground,
      body: Row(
        children: [
          _SideNav(
            section: section,
            onSectionChanged: onSectionChanged,
            onLogout: onLogout,
          ),
          Expanded(
            child: Column(
              children: [
                Material(
                  color: PageShellTheme.appBarBackground,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 56,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const _BrandTitle(),
                            const Spacer(),
                            const AnnouncementsBellButton(iconColor: Colors.black87),
                            const CreditCoreSiteIconButton(),
                            IconButton(
                              tooltip: 'Esci',
                              onPressed: () => onLogout(),
                              icon: const Icon(Icons.logout),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: child),
                const _VersionFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final CreditCalcNavItem section;
  final ValueChanged<CreditCalcNavItem> onSectionChanged;
  final Future<void> Function() onLogout;

  const _SideNav({
    required this.section,
    required this.onSectionChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PageShellTheme.drawerBackground,
      child: SafeArea(
        child: SizedBox(
          width: PageShellTheme.sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  'CreditCalc',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ProjectColors.calc,
                  ),
                ),
              ),
              _NavTile(
                icon: Icons.account_balance,
                label: 'Creditori',
                selected: section == CreditCalcNavItem.creditors,
                onTap: () => onSectionChanged(CreditCalcNavItem.creditors),
              ),
              _NavTile(
                icon: Icons.calculate,
                label: 'Sviluppa',
                selected: section == CreditCalcNavItem.develop,
                onTap: () => onSectionChanged(CreditCalcNavItem.develop),
              ),
              _NavTile(
                icon: Icons.payments,
                label: 'Provvigioni',
                selected: section == CreditCalcNavItem.commissions,
                onTap: () => onSectionChanged(CreditCalcNavItem.commissions),
              ),
              const Spacer(),
              const CreditCoreSiteListTile(dense: true),
              ListTile(
                dense: true,
                leading: const Icon(Icons.logout, size: 20),
                title: const Text('Esci', style: TextStyle(fontSize: 14)),
                onTap: () => onLogout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: ProjectColors.calc.withValues(alpha: 0.12),
      leading: Icon(icon, color: selected ? ProjectColors.calc : null, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? ProjectColors.calc : null,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: const [
          TextSpan(
            text: 'Credit',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          TextSpan(
            text: 'Calc',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ProjectColors.calc,
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final version = snap.data?.version ?? '…';
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'v$version',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        );
      },
    );
  }
}
