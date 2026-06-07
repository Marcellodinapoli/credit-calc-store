import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/maintenance_service.dart';
import '../shell/credit_core_account_menu_sheet.dart';
import '../ui/layout/page_shell.dart';
import 'maintenance_blocked_view.dart';

/// Blocca l'intera app CreditCalc (inclusi route root) quando la sezione
/// è in manutenzione su Firestore (`settings/maintenance`).
class CreditCalcMaintenanceGate extends StatefulWidget {
  final Widget child;

  const CreditCalcMaintenanceGate({super.key, required this.child});

  @override
  State<CreditCalcMaintenanceGate> createState() =>
      _CreditCalcMaintenanceGateState();
}

class _CreditCalcMaintenanceGateState extends State<CreditCalcMaintenanceGate> {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: MaintenanceService.watch(),
      builder: (context, snapshot) {
        final data = MaintenanceService.dataFrom(snapshot.data);
        final blocked = MaintenanceService.isSectionBlocked(
          data,
          MaintenanceService.creditCalc,
        );

        _handleBlockedTransition(blocked);

        if (!blocked) return widget.child;

        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(child: widget.child),
            Material(
              color: PageShellTheme.scaffoldBackground,
              child: SafeArea(
                child: Column(
                  children: [
                    Material(
                      color: PageShellTheme.appBarBackground,
                      child: SizedBox(
                        height: 56,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: _BrandTitle(),
                              ),
                              const Spacer(),
                              const AnnouncementsBellButton(
                                iconColor: Colors.black87,
                              ),
                              IconButton(
                                tooltip: 'Menu',
                                onPressed: _showAccountMenu,
                                icon: const Icon(Icons.more_vert),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: MaintenanceBlockedView(
                        sectionName: MaintenanceService.creditCalc,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
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
