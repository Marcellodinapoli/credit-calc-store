import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/maintenance_service.dart';
import '../../services/account_menu_badge_controller.dart';
import '../../session/credit_core_session_runtime.dart';
import '../../shell/credit_core_account_menu_sheet.dart';
import '../../shell/credit_core_module_navigation.dart';
import '../../ui/layout/page_shell.dart';
import '../../pages/area/personal_area_menu.dart';
import '../../widgets/account_menu_badge_icon_button.dart';
import '../../widgets/maintenance_section_gate.dart';

/// Layout secondario per pagine Area personale (titolo + indietro).
class PersonalAreaShell extends StatefulWidget {
  final String pageTitle;
  final Widget body;
  final Widget? bottomBar;
  final bool bypassMaintenance;
  final String maintenanceSection;
  final bool showAccountMenu;
  final PersonalAreaMenuItem? activeMenuItem;
  final bool backToCreditCalcHome;

  const PersonalAreaShell({
    super.key,
    required this.pageTitle,
    required this.body,
    this.bottomBar,
    this.bypassMaintenance = false,
    this.maintenanceSection = MaintenanceService.area,
    this.showAccountMenu = true,
    this.activeMenuItem,
    this.backToCreditCalcHome = false,
  });

  @override
  State<PersonalAreaShell> createState() => _PersonalAreaShellState();
}

class _PersonalAreaShellState extends State<PersonalAreaShell> {
  final _accountMenuBadgeController = AccountMenuBadgeController();

  @override
  void initState() {
    super.initState();
    if (widget.showAccountMenu) {
      _accountMenuBadgeController.start();
    }
  }

  @override
  void dispose() {
    if (widget.showAccountMenu) {
      _accountMenuBadgeController.stop();
    }
    super.dispose();
  }

  Future<void> _logout() async {
    await CreditCoreSessionRuntime.signOutWithSessionRelease();
  }

  void _openAnnouncements() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AnnouncementsPage(),
      ),
    );
  }

  void _showAccountMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => CreditCoreAccountMenuSheet(
        onAnnouncements: _openAnnouncements,
        onLogout: _logout,
        selectedAreaItem:
            widget.showAccountMenu ? widget.activeMenuItem : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themedBody = MaintenanceSectionGate(
      sectionName: widget.maintenanceSection,
      enabled: !widget.bypassMaintenance,
      child: widget.body,
    );

    if (widget.showAccountMenu) {
      return PrimaryModuleScaffold(
        project: BrandedPageProject.area,
        pageTitle: widget.pageTitle,
        automaticallyImplyLeading: !widget.backToCreditCalcHome,
        onBackPressed: widget.backToCreditCalcHome
            ? () => popToCreditCalcHome(context)
            : null,
        bottomBar: widget.bottomBar,
        extraAppBarActions: [
          AccountMenuBadgeIconButton(onPressed: _showAccountMenu),
        ],
        body: themedBody,
      );
    }

    return SecondaryPageScaffold(
      pageTitle: widget.pageTitle,
      project: BrandedPageProject.area,
      bottomBar: widget.bottomBar,
      body: themedBody,
    );
  }
}
