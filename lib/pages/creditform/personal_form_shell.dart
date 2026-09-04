import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../core/form_theme.dart';
import '../../core/maintenance_service.dart';
import '../../session/credit_core_session_runtime.dart';
import '../../pages/creditform/personal_form_menu.dart';
import '../../services/account_menu_badge_controller.dart';
import '../../shell/credit_core_account_menu_sheet.dart';
import '../../shell/credit_core_module_navigation.dart';
import '../../ui/layout/page_shell.dart';
import '../../widgets/account_menu_badge_icon_button.dart';
import '../../widgets/maintenance_section_gate.dart';

class PersonalFormShell extends StatefulWidget {
  final String pageTitle;
  final Widget body;
  final Widget? bottomBar;
  final bool padded;
  final bool showAccountMenu;
  final PersonalFormMenuItem? activeMenuItem;

  const PersonalFormShell({
    super.key,
    required this.pageTitle,
    required this.body,
    this.bottomBar,
    this.padded = true,
    this.showAccountMenu = false,
    this.activeMenuItem,
  });

  @override
  State<PersonalFormShell> createState() => _PersonalFormShellState();
}

class _PersonalFormShellState extends State<PersonalFormShell> {
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
    await CreditCoreSessionRuntime.signOutAndClearNavigation(context);
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
        selectedFormItem:
            widget.showAccountMenu ? widget.activeMenuItem : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themedBody = MaintenanceSectionGate(
      sectionName: MaintenanceService.creditForm,
      child: Theme(
        data: buildFormTheme(),
        child: widget.body,
      ),
    );

    return PrimaryModuleScaffold(
      project: BrandedPageProject.form,
      pageTitle: widget.pageTitle,
      automaticallyImplyLeading: !widget.showAccountMenu,
      onBackPressed:
          widget.showAccountMenu ? () => popToCreditCalcHome(context) : null,
      bottomBar: widget.bottomBar == null
          ? null
          : Theme(data: buildFormTheme(), child: widget.bottomBar!),
      extraAppBarActions: widget.showAccountMenu
          ? [AccountMenuBadgeIconButton(onPressed: _showAccountMenu)]
          : null,
      body: themedBody,
    );
  }
}
