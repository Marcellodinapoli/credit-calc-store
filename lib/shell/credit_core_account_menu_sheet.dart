import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/maintenance_service.dart';
import '../core/admin/bk_admin_service.dart';
import '../pages/area/personal_area_menu.dart';
import '../pages/bk/bk_coupons_page.dart';
import '../pages/bk/bk_warmup_monitoring_page.dart';
import '../pages/bk/bk_warmup_contestations_page.dart';
import '../pages/bk/bk_call_analysis_page.dart';
import '../pages/bk/bk_normative_search_page.dart';
import '../pages/bk/bk_ecosystem_sections_page.dart';
import '../pages/bk/bk_plan_limits_page.dart';
import '../pages/creditcalc/device_sync_page.dart';
import '../shell/credit_core_module_navigation.dart';
import '../services/account_menu_badge_notifier.dart';
import '../ui/layout/page_shell.dart';
import '../pages/creditform/personal_form_menu.dart';
import '../pages/creditjob/personal_job_menu.dart';
import '../widgets/account_menu_badge_icon_button.dart';
import 'credit_core_site_actions.dart';

enum _MenuSection { creditForm, creditJob }

/// Menù account mobile allineato a CreditPlanet (`SingleMenu`), filtrato per tipo utente.
class CreditCoreAccountMenuSheet extends StatefulWidget {
  final VoidCallback onAnnouncements;
  final Future<void> Function() onLogout;
  final PersonalFormMenuItem? selectedFormItem;
  final PersonalJobMenuItem? selectedJobItem;
  final PersonalAreaMenuItem? selectedAreaItem;
  final bool selectedSync;

  const CreditCoreAccountMenuSheet({
    super.key,
    required this.onAnnouncements,
    required this.onLogout,
    this.selectedFormItem,
    this.selectedJobItem,
    this.selectedAreaItem,
    this.selectedSync = false,
  });

  @override
  State<CreditCoreAccountMenuSheet> createState() =>
      _CreditCoreAccountMenuSheetState();
}

class _CreditCoreAccountMenuSheetState extends State<CreditCoreAccountMenuSheet> {
  static const _formColor = Color(0xFFFFA726);
  static const _jobColor = Color(0xFF00C4B3);
  static const _areaColor = Color(0xFF1565C0);

  static final _formLight = _formColor.withValues(alpha: 0.15);
  static final _jobLight = _jobColor.withValues(alpha: 0.15);

  _MenuSection? _openSection;
  String? _userType;
  String? _workRole;
  bool _blockedContext = false;
  bool _isBkAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.selectedFormItem != null) {
      _openSection = _MenuSection.creditForm;
    } else if (widget.selectedJobItem != null) {
      _openSection = _MenuSection.creditJob;
    }
    _loadUserContext();
  }

  Future<void> _loadUserContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _userType = 'public';
        _loading = false;
      });
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      final userStatus = (data['status'] ?? '').toString();
      final type = (data['type'] ?? 'public').toString();
      final companyId = (data['companyId'] ?? '').toString();
      var companyBlocked = false;

      if (companyId.isNotEmpty) {
        try {
          final companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .get();
          if (companyDoc.exists) {
            companyBlocked = UserAccountStatus.isBlocked(
              (companyDoc.data()?['status'] ?? '').toString(),
            );
          }
        } catch (_) {}
      } else if (type == 'company') {
        try {
          final companyDoc = await FirebaseFirestore.instance
              .collection('companies')
              .doc(user.uid)
              .get();
          if (companyDoc.exists) {
            companyBlocked = UserAccountStatus.isBlocked(
              (companyDoc.data()?['status'] ?? '').toString(),
            );
          }
        } catch (_) {}
      }

      if (!mounted) return;
      final isBkAdmin = await BkAdminService.isAdmin();
      if (!mounted) return;
      setState(() {
        _userType = type;
        _workRole = (data['workRole'] ?? '').toString().trim();
        _blockedContext =
            UserAccountStatus.isBlocked(userStatus) || companyBlocked;
        _isBkAdmin = isBkAdmin;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userType = 'public';
        _loading = false;
      });
    }
  }

  void _closeAnd(VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  void _closeAndForm(PersonalFormMenuItem item) {
    if (widget.selectedFormItem == item) {
      Navigator.pop(context);
      return;
    }
    _closeAnd(() => item.open(context));
  }

  void _closeAndJob(PersonalJobMenuItem item) {
    if (widget.selectedJobItem == item) {
      Navigator.pop(context);
      return;
    }
    _closeAnd(() => item.open(context));
  }

  void _closeAndArea(PersonalAreaMenuItem item) {
    if (widget.selectedAreaItem == item) {
      Navigator.pop(context);
      return;
    }
    _closeAnd(() => item.open(context));
  }

  void _closeAndSync() {
    if (widget.selectedSync) {
      Navigator.pop(context);
      return;
    }
    _closeAnd(() {
      Navigator.of(context).push(
        creditCoreModuleRoute<void>(
          (_) => const DeviceSyncPage(),
        ),
      );
    });
  }

  void _showMaintenanceSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sezione in manutenzione')),
    );
  }

  Widget _buildExpandableSectionTitle(
    BrandedPageProject project,
    _MenuSection section,
    Map<String, dynamic>? maintenanceData, {
    bool showBadge = false,
  }) {
    final isOpen = _openSection == section;
    final sectionName = switch (section) {
      _MenuSection.creditForm => MaintenanceService.creditForm,
      _MenuSection.creditJob => MaintenanceService.creditJob,
    };
    final blocked = MaintenanceService.isSectionBlocked(maintenanceData, sectionName);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: BrandedProjectName(project: project, fontSize: 16),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBadge) ...[
            accountMenuBadgeDot(visible: true),
            const SizedBox(width: 8),
          ],
          if (blocked)
            const Icon(Icons.warning_amber_rounded, color: Colors.orange)
          else
            Icon(isOpen ? Icons.remove : Icons.add),
        ],
      ),
      onTap: blocked
          ? _showMaintenanceSnackBar
          : () {
              setState(() {
                _openSection = isOpen ? null : section;
              });
            },
    );
  }

  Widget _buildSubMenuItem(
    String title,
    VoidCallback onTap,
    Color accent,
    Color accentLight,
    Map<String, dynamic>? maintenanceData,
    String sectionName, {
    bool showBadge = false,
    bool selected = false,
  }) {
    final blocked = MaintenanceService.isSectionBlocked(maintenanceData, sectionName);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        '- $title',
        style: TextStyle(
          color: blocked
              ? Colors.black38
              : selected
                  ? accent
                  : Colors.black87,
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBadge) ...[
            accountMenuBadgeDot(visible: true),
            const SizedBox(width: 8),
          ],
          if (selected)
            Icon(Icons.check_circle, color: accent, size: 20),
        ],
      ),
      tileColor: selected
          ? accent.withValues(alpha: 0.18)
          : accentLight.withValues(alpha: 0.35),
      shape: selected
          ? Border(
              left: BorderSide(color: accent, width: 3),
            )
          : null,
      onTap: blocked ? _showMaintenanceSnackBar : onTap,
    );
  }

  Widget _areaHeader({bool showBadge = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          const Expanded(
      child: Text(
        'Area personale',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          accountMenuBadgeDot(visible: showBadge),
        ],
      ),
    );
  }

  double _topInset(BuildContext context) {
    final viewTop = MediaQuery.viewPaddingOf(context).top;
    if (viewTop > 0) return viewTop;
    return MediaQuery.paddingOf(context).top;
  }

  Widget _menuHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, _topInset(context) + 4, 4, 0),
      child: Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'Menù',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Chiudi',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    bool showBadge = false,
    bool selected = false,
  }) {
    final accent = iconColor ?? Colors.black54;
    return ListTile(
      leading: Icon(icon, color: selected ? _areaColor : accent),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          color: selected ? _areaColor : Colors.black87,
        ),
      ),
      trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
          if (showBadge) ...[
            accountMenuBadgeDot(visible: true),
            const SizedBox(width: 8),
          ],
          if (selected) Icon(Icons.check_circle, color: _areaColor, size: 20),
        ],
      ),
      tileColor: selected ? _areaColor.withValues(alpha: 0.12) : null,
      shape: selected
          ? const Border(
              left: BorderSide(color: _areaColor, width: 3),
            )
          : null,
      onTap: onTap,
    );
  }

  bool _formItemBadge(PersonalFormMenuItem item, AccountMenuBadges badges) {
    return switch (item) {
      PersonalFormMenuItem.courses => badges.courses,
      PersonalFormMenuItem.listening => badges.warmup,
      PersonalFormMenuItem.roleplay => badges.roleplay,
      _ => false,
    };
  }

  bool _jobItemBadge(PersonalJobMenuItem item, AccountMenuBadges badges) {
    return switch (item) {
      PersonalJobMenuItem.jobOffers => badges.jobOffers,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _userType == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _menuHeader(),
          const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
        ],
      );
    }

    final isPublic = _userType == 'public';
    final isCompany = _userType == 'company';
    final isWork = _userType == 'work';
    final isSupervisor = isWork && _workRole == 'supervisor';

    return StreamBuilder(
      stream: MaintenanceService.watch(),
      builder: (context, maintenanceSnap) {
        final maintenanceData = MaintenanceService.dataFrom(maintenanceSnap.data);
        final formBlocked = MaintenanceService.isSectionBlocked(
          maintenanceData,
          MaintenanceService.creditForm,
        );
        final jobBlocked = MaintenanceService.isSectionBlocked(
          maintenanceData,
          MaintenanceService.creditJob,
        );
        final areaBlocked = MaintenanceService.isSectionBlocked(
          maintenanceData,
          MaintenanceService.area,
        );

        return ValueListenableBuilder<AccountMenuBadges>(
          valueListenable: AccountMenuBadgeNotifier.instance.badges,
          builder: (context, badges, _) {
        final children = <Widget>[
          _menuHeader(),
          const Divider(),
          _item(
            icon: Icons.notifications_outlined,
            title: 'Notifiche',
            showBadge: badges.announcements,
            onTap: () => _closeAnd(widget.onAnnouncements),
          ),
        ];

        if (_blockedContext) {
          children.addAll([
                _areaHeader(showBadge: badges.hasArea),
            _item(
              icon: Icons.support_agent_outlined,
              title: PersonalAreaMenuItem.directSupport.title,
              iconColor: _areaColor,
                  showBadge: badges.directSupport,
              onTap: () => _closeAndArea(PersonalAreaMenuItem.directSupport),
            ),
          ]);
        } else {
          final showForm = !isCompany;
          final showJob = isPublic || isCompany;

          if (showForm) {
            children.add(
              _buildExpandableSectionTitle(
                BrandedPageProject.form,
                _MenuSection.creditForm,
                maintenanceData,
                    showBadge: badges.hasCreditForm,
              ),
            );
            if (_openSection == _MenuSection.creditForm && !formBlocked) {
              if (isSupervisor) {
                children.add(_buildSubMenuItem(
                  PersonalFormMenuItem.companyCollaborators.title,
                  () => _closeAndForm(PersonalFormMenuItem.companyCollaborators),
                  _formColor,
                  _formLight,
                  maintenanceData,
                  MaintenanceService.creditForm,
                      selected: widget.selectedFormItem ==
                          PersonalFormMenuItem.companyCollaborators,
                ));
              }
              for (final item in [
                PersonalFormMenuItem.courses,
                PersonalFormMenuItem.listening,
                PersonalFormMenuItem.roleplay,
                PersonalFormMenuItem.progress,
                PersonalFormMenuItem.review,
              ]) {
                children.add(_buildSubMenuItem(
                  item.title,
                  () => _closeAndForm(item),
                  _formColor,
                  _formLight,
                  maintenanceData,
                  MaintenanceService.creditForm,
                      showBadge: _formItemBadge(item, badges),
                      selected: widget.selectedFormItem == item,
                ));
              }
            }
          }

          if (showJob) {
            children.add(
              _buildExpandableSectionTitle(
                BrandedPageProject.job,
                _MenuSection.creditJob,
                maintenanceData,
                    showBadge: badges.hasCreditJob,
              ),
            );
            if (_openSection == _MenuSection.creditJob && !jobBlocked) {
              if (isCompany) {
                children.addAll([
                  _buildSubMenuItem(
                    PersonalJobMenuItem.gestioneLavori.title,
                    () => _closeAndJob(PersonalJobMenuItem.gestioneLavori),
                    _jobColor,
                    _jobLight,
                    maintenanceData,
                    MaintenanceService.creditJob,
                        selected: widget.selectedJobItem ==
                            PersonalJobMenuItem.gestioneLavori,
                  ),
                  _buildSubMenuItem(
                    PersonalJobMenuItem.companyUsers.title,
                    () => _closeAndJob(PersonalJobMenuItem.companyUsers),
                    _jobColor,
                    _jobLight,
                    maintenanceData,
                    MaintenanceService.creditJob,
                        selected: widget.selectedJobItem ==
                            PersonalJobMenuItem.companyUsers,
                  ),
                ]);
              } else if (isPublic) {
                children.addAll([
                  _buildSubMenuItem(
                    PersonalJobMenuItem.jobOffers.title,
                    () => _closeAndJob(PersonalJobMenuItem.jobOffers),
                    _jobColor,
                    _jobLight,
                    maintenanceData,
                    MaintenanceService.creditJob,
                        showBadge: _jobItemBadge(
                          PersonalJobMenuItem.jobOffers,
                          badges,
                        ),
                        selected: widget.selectedJobItem ==
                            PersonalJobMenuItem.jobOffers,
                  ),
                  _buildSubMenuItem(
                    PersonalJobMenuItem.savedJobs.title,
                    () => _closeAndJob(PersonalJobMenuItem.savedJobs),
                    _jobColor,
                    _jobLight,
                    maintenanceData,
                    MaintenanceService.creditJob,
                        selected: widget.selectedJobItem ==
                            PersonalJobMenuItem.savedJobs,
                  ),
                  _buildSubMenuItem(
                    PersonalJobMenuItem.myApplications.title,
                    () => _closeAndJob(PersonalJobMenuItem.myApplications),
                    _jobColor,
                    _jobLight,
                    maintenanceData,
                    MaintenanceService.creditJob,
                        selected: widget.selectedJobItem ==
                            PersonalJobMenuItem.myApplications,
                  ),
                ]);
              }
            }
          }

          children.addAll([
            const Divider(height: 24),
                _areaHeader(showBadge: badges.hasArea),
            if (!areaBlocked) ...[
              _item(
                icon: Icons.person_outline,
                title: PersonalAreaMenuItem.myData.title,
                iconColor: _areaColor,
                    selected:
                        widget.selectedAreaItem == PersonalAreaMenuItem.myData,
                onTap: () => _closeAndArea(PersonalAreaMenuItem.myData),
              ),
              if (!isWork)
                _item(
                  icon: Icons.card_membership_outlined,
                  title: PersonalAreaMenuItem.subscription.title,
                  iconColor: _areaColor,
                      selected: widget.selectedAreaItem ==
                          PersonalAreaMenuItem.subscription,
                  onTap: () =>
                      _closeAndArea(PersonalAreaMenuItem.subscription),
                    ),
                  _item(
                    icon: Icons.sync_alt,
                    title: 'Sincronizza',
                    iconColor: _areaColor,
                    selected: widget.selectedSync,
                    onTap: _closeAndSync,
                ),
              _item(
                icon: Icons.groups_outlined,
                title: PersonalAreaMenuItem.community.title,
                iconColor: _areaColor,
                    showBadge: badges.community,
                    selected: widget.selectedAreaItem ==
                        PersonalAreaMenuItem.community,
                onTap: () => _closeAndArea(PersonalAreaMenuItem.community),
              ),
                  _item(
                    icon: Icons.support_agent_outlined,
                    title: PersonalAreaMenuItem.directSupport.title,
                    iconColor: _areaColor,
                    showBadge: badges.directSupport,
                    selected: widget.selectedAreaItem ==
                        PersonalAreaMenuItem.directSupport,
                    onTap: () => _closeAndArea(PersonalAreaMenuItem.directSupport),
                  ),
              _item(
                icon: Icons.menu_book_outlined,
                title: PersonalAreaMenuItem.guide.title,
                iconColor: _areaColor,
                    selected:
                        widget.selectedAreaItem == PersonalAreaMenuItem.guide,
                onTap: () => _closeAndArea(PersonalAreaMenuItem.guide),
              ),
              _item(
                icon: Icons.tune_outlined,
                title: PersonalAreaMenuItem.notificationPreferences.title,
                iconColor: _areaColor,
                    selected: widget.selectedAreaItem ==
                        PersonalAreaMenuItem.notificationPreferences,
                    onTap: () => _closeAndArea(
                      PersonalAreaMenuItem.notificationPreferences,
                    ),
              ),
              _item(
                icon: Icons.privacy_tip_outlined,
                title: PersonalAreaMenuItem.privacyConsents.title,
                iconColor: _areaColor,
                    selected: widget.selectedAreaItem ==
                        PersonalAreaMenuItem.privacyConsents,
                    onTap: () =>
                        _closeAndArea(PersonalAreaMenuItem.privacyConsents),
              ),
            ],
            if (_isBkAdmin) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Backoffice',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _item(
                icon: Icons.confirmation_number_outlined,
                title: 'Coupon registrazione',
                iconColor: _areaColor,
                onTap: () => _closeAnd(() {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BkCouponsPage(),
                    ),
                  );
                }),
              ),
                  _item(
                    icon: Icons.speed_outlined,
                    title: 'Piani FREE / PLUS / ENTERPRISE',
                    iconColor: _areaColor,
                    onTap: () => _closeAnd(() {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BkPlanLimitsPage(),
                        ),
                      );
                    }),
                  ),
                  _item(
                    icon: Icons.view_module_outlined,
                    title: 'Sezioni ecosistema',
                    iconColor: _areaColor,
                    onTap: () => _closeAnd(() {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BkEcosystemSectionsPage(),
                        ),
                      );
                    }),
                  ),
                  _item(
                    icon: Icons.school_outlined,
                    title: 'Warm-up telefonata e contestazioni',
                    iconColor: _areaColor,
                    onTap: () => _closeAnd(() {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const BkWarmupMonitoringPage(),
                        ),
                      );
                    }),
                  ),
              _item(
                icon: Icons.record_voice_over_outlined,
                    title: 'Moderazione contestazioni utenti',
                iconColor: _areaColor,
                onTap: () => _closeAnd(() {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BkWarmupContestationsPage(),
                    ),
                  );
                }),
              ),
              _item(
                    icon: Icons.search_outlined,
                title: 'Prompt ricerca normativa',
                iconColor: _areaColor,
                onTap: () => _closeAnd(() {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BkNormativeSearchPage(),
                    ),
                  );
                }),
              ),
              _item(
                icon: Icons.call_outlined,
                title: 'Prompt analisi telefonata',
                iconColor: _areaColor,
                onTap: () => _closeAnd(() {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BkCallAnalysisPage(),
                    ),
                  );
                }),
              ),
            ],
          ]);
        }

        children.addAll([
          const Divider(height: 16),
          _CreditCoreSiteListTileInline(
            userType: _userType,
            onBeforeOpen: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Esci'),
                onTap: () async {
              Navigator.pop(context);
                  await widget.onLogout();
            },
          ),
          SizedBox(height: MediaQuery.viewPaddingOf(context).bottom + 8),
        ]);

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
            );
          },
        );
      },
    );
  }
}

class _CreditCoreSiteListTileInline extends StatelessWidget {
  final String? userType;
  final VoidCallback? onBeforeOpen;

  const _CreditCoreSiteListTileInline({
    required this.userType,
    this.onBeforeOpen,
  });

  @override
  Widget build(BuildContext context) {
    final portal = CreditCoreSiteUrls.portalLabelForUserType(userType);
    final siteHost = CreditCoreSiteUrls.hostForUserType(userType);
    return ListTile(
      leading: const Icon(Icons.language),
      title: const Text('Vai al sito CreditCore'),
      subtitle: Text('$portal · $siteHost'),
      onTap: () {
        onBeforeOpen?.call();
        openCreditCoreSite(context, userType);
      },
    );
  }
}
