import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/maintenance_service.dart';
import '../shell/credit_core_account_menu_sheet.dart';
import '../ui/layout/page_shell.dart';
import 'maintenance_blocked_view.dart';

/// Mostra [MaintenanceBlockedView] quando la sezione è in manutenzione su Firestore.
class MaintenanceSectionGate extends StatefulWidget {
  final String sectionName;
  final Widget child;
  final bool enabled;

  /// Sostituisce l'intero [child] (es. shell CreditCalc) con schermata blocco.
  final bool fullScreen;

  const MaintenanceSectionGate({
    super.key,
    required this.sectionName,
    required this.child,
    this.enabled = true,
    this.fullScreen = false,
  });

  @override
  State<MaintenanceSectionGate> createState() => _MaintenanceSectionGateState();
}

class _MaintenanceSectionGateState extends State<MaintenanceSectionGate> {
  bool _wasBlocked = false;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _showAccountMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CreditCoreAccountMenuSheet(
        onAnnouncements: () {
          Navigator.of(context).pop();
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

  void _handleBlockedTransition(bool blocked) {
    if (!widget.fullScreen) return;

    if (blocked && !_wasBlocked) {
      _wasBlocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
      });
      return;
    }

    if (!blocked) {
      _wasBlocked = false;
    }
  }

  Widget _fullScreenBlocked() {
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
      body: MaintenanceBlockedView(sectionName: widget.sectionName),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: MaintenanceService.watch(),
      builder: (context, snap) {
        final payload = MaintenanceService.dataFrom(snap.data);
        final blocked = MaintenanceService.isSectionBlocked(
          payload,
          widget.sectionName,
        );

        _handleBlockedTransition(blocked);

        if (!blocked) return widget.child;

        if (widget.fullScreen) {
          return _fullScreenBlocked();
        }

        return MaintenanceBlockedView(sectionName: widget.sectionName);
      },
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
