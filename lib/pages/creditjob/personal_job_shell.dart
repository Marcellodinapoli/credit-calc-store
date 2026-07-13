import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/job_theme.dart';
import '../../core/maintenance_service.dart';
import '../../session/credit_core_session_runtime.dart';
import '../../pages/creditjob/personal_job_menu.dart';
import '../../services/account_menu_badge_controller.dart';
import '../../shell/credit_core_account_menu_sheet.dart';
import '../../shell/credit_core_module_navigation.dart';
import '../../ui/layout/page_shell.dart';
import '../../widgets/account_menu_badge_icon_button.dart';
import '../../widgets/maintenance_section_gate.dart';

/// Layout principale per pagine CreditJob (tema verde sul contenuto).
class PersonalJobShell extends StatefulWidget {
  final String pageTitle;
  final Widget body;
  final Widget? bottomBar;
  final bool padded;
  final bool showAccountMenu;
  final PersonalJobMenuItem? activeMenuItem;

  const PersonalJobShell({
    super.key,
    required this.pageTitle,
    required this.body,
    this.bottomBar,
    this.padded = true,
    this.showAccountMenu = false,
    this.activeMenuItem,
  });

  @override
  State<PersonalJobShell> createState() => _PersonalJobShellState();
}

class _PersonalJobShellState extends State<PersonalJobShell> {
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
        selectedJobItem: widget.showAccountMenu ? widget.activeMenuItem : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themedBody = MaintenanceSectionGate(
      sectionName: MaintenanceService.creditJob,
      child: Theme(
        data: buildJobTheme(),
        child: widget.body,
      ),
    );

    return PrimaryModuleScaffold(
      project: BrandedPageProject.job,
      pageTitle: widget.pageTitle,
      automaticallyImplyLeading: !widget.showAccountMenu,
      onBackPressed:
          widget.showAccountMenu ? () => popToCreditCalcHome(context) : null,
      bottomBar: widget.bottomBar == null
          ? null
          : Theme(data: buildJobTheme(), child: widget.bottomBar!),
      extraAppBarActions: widget.showAccountMenu
          ? [AccountMenuBadgeIconButton(onPressed: _showAccountMenu)]
          : null,
      body: themedBody,
    );
  }
}
