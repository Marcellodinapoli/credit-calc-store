import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/maintenance_service.dart';
import '../pages/area/personal_area_menu.dart';
import '../ui/layout/page_shell.dart';
import '../pages/creditform/personal_form_menu.dart';
import '../pages/creditjob/personal_job_menu.dart';
import 'credit_core_site_actions.dart';

enum _MenuSection { creditForm, creditJob }

/// Menù account mobile allineato a CreditPlanet (`SingleMenu`), filtrato per tipo utente.
class CreditCoreAccountMenuSheet extends StatefulWidget {
  final VoidCallback onAnnouncements;
  final Future<void> Function() onLogout;

  const CreditCoreAccountMenuSheet({
    super.key,
    required this.onAnnouncements,
    required this.onLogout,
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
      setState(() {
        _userType = type;
        _workRole = (data['workRole'] ?? '').toString().trim();
        _blockedContext =
            UserAccountStatus.isBlocked(userStatus) || companyBlocked;
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
    _closeAnd(() => item.open(context));
  }

  void _closeAndJob(PersonalJobMenuItem item) {
    _closeAnd(() => item.open(context));
  }

  void _closeAndArea(PersonalAreaMenuItem item) {
    _closeAnd(() => item.open(context));
  }

  void _showMaintenanceSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sezione in manutenzione')),
    );
  }

  Widget _buildExpandableSectionTitle(
    BrandedPageProject project,
    _MenuSection section,
    Map<String, dynamic>? maintenanceData,
  ) {
    final isOpen = _openSection == section;
    final sectionName = section == _MenuSection.creditForm
        ? MaintenanceService.creditForm
        : MaintenanceService.creditJob;
    final blocked = MaintenanceService.isSectionBlocked(maintenanceData, sectionName);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: BrandedProjectName(project: project, fontSize: 16),
      trailing: blocked
          ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
          : Icon(isOpen ? Icons.remove : Icons.add),
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
    String sectionName,
  ) {
    final blocked = MaintenanceService.isSectionBlocked(maintenanceData, sectionName);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        '- $title',
        style: TextStyle(color: blocked ? Colors.black38 : Colors.black87),
      ),
      tileColor: accentLight.withValues(alpha: 0.35),
      onTap: blocked ? _showMaintenanceSnackBar : onTap,
    );
  }

  Widget _areaHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        'Area personale',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.black54),
      title: Text(title),
      onTap: onTap,
    );
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

        final children = <Widget>[
          _menuHeader(),
          const Divider(),
          _item(
            icon: Icons.notifications_outlined,
            title: 'Notifiche',
            onTap: () => _closeAnd(widget.onAnnouncements),
          ),
        ];

        if (_blockedContext) {
          children.addAll([
            _areaHeader(),
            _item(
              icon: Icons.support_agent_outlined,
              title: PersonalAreaMenuItem.directSupport.title,
              iconColor: _areaColor,
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
                  ),
                  _buildSubMenuItem(
                    PersonalJobMenuItem.companyUsers.title,
                    () => _closeAndJob(PersonalJobMenuItem.companyUsers),
                    _jobColor,
                    _jobLight,
                    maintenanceData,
                    MaintenanceService.creditJob,
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
                  ),
                  _buildSubMenuItem(
                    PersonalJobMenuItem.savedJobs.title,
                    () => _closeAndJob(PersonalJobMenuItem.savedJobs),
                    _jobColor,
                    _jobLight,
                    maintenanceData,
                    MaintenanceService.creditJob,
                  ),
                  _buildSubMenuItem(
                    PersonalJobMenuItem.myApplications.title,
                    () => _closeAndJob(PersonalJobMenuItem.myApplications),
                    _jobColor,
                    _jobLight,
                    maintenanceData,
                    MaintenanceService.creditJob,
                  ),
                ]);
              }
            }
          }

          children.addAll([
            const Divider(height: 24),
            _areaHeader(),
            if (!areaBlocked) ...[
              _item(
                icon: Icons.route_outlined,
                title: PersonalAreaMenuItem.visitItinerary.title,
                iconColor: _areaColor,
                onTap: () => _closeAndArea(PersonalAreaMenuItem.visitItinerary),
              ),
              _item(
                icon: Icons.person_outline,
                title: PersonalAreaMenuItem.myData.title,
                iconColor: _areaColor,
                onTap: () => _closeAndArea(PersonalAreaMenuItem.myData),
              ),
              _item(
                icon: Icons.groups_outlined,
                title: PersonalAreaMenuItem.community.title,
                iconColor: _areaColor,
                onTap: () => _closeAndArea(PersonalAreaMenuItem.community),
              ),
              _item(
                icon: Icons.menu_book_outlined,
                title: PersonalAreaMenuItem.guide.title,
                iconColor: _areaColor,
                onTap: () => _closeAndArea(PersonalAreaMenuItem.guide),
              ),
              _item(
                icon: Icons.tune_outlined,
                title: PersonalAreaMenuItem.notificationPreferences.title,
                iconColor: _areaColor,
                onTap: () =>
                    _closeAndArea(PersonalAreaMenuItem.notificationPreferences),
              ),
              _item(
                icon: Icons.privacy_tip_outlined,
                title: PersonalAreaMenuItem.privacyConsents.title,
                iconColor: _areaColor,
                onTap: () => _closeAndArea(PersonalAreaMenuItem.privacyConsents),
              ),
            ],
            _item(
              icon: Icons.support_agent_outlined,
              title: PersonalAreaMenuItem.directSupport.title,
              iconColor: _areaColor,
              onTap: () => _closeAndArea(PersonalAreaMenuItem.directSupport),
            ),
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
            onTap: () {
              Navigator.pop(context);
              widget.onLogout();
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
