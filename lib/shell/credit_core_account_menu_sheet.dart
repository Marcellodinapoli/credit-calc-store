import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart'
    hide CommissionsPage, CreditorsPage, DevelopPage;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/maintenance_service.dart';
import '../core/admin/bk_admin_service.dart';
import '../pages/area/personal_area_menu.dart';
import '../pages/bk/bk_coupons_page.dart';
import '../pages/bk/bk_warmup_contestations_page.dart';
import '../pages/bk/bk_normative_search_page.dart';
import '../pages/bk/bk_call_analysis_page.dart';
import '../pages/bk/bk_plan_limits_page.dart';
import '../models/field_activity.dart';
import '../models/field_reminder.dart';
import '../models/field_visit.dart';
import '../services/field_activity_service.dart';
import '../services/field_reminder_service.dart';
import '../services/field_visit_service.dart';
import '../services/gestione_menu_badge_service.dart';
import '../services/read_state_service.dart';
import '../pages/creditcalc/commissions_page.dart';
import '../pages/creditcalc/creditors_page.dart';
import '../pages/creditcalc/develop_page.dart';
import '../widgets/itinerary_day_summary_card.dart';
import '../pages/creditcalc/installment_monitor_page.dart';
import '../pages/creditcalc/itinerary/activities_page.dart';
import '../pages/creditcalc/itinerary/practice_agenda_page.dart';
import '../pages/creditcalc/itinerary/reminders_page.dart';
import '../pages/creditcalc/itinerary/territory_map_page.dart';
import '../pages/creditcalc/itinerary/visit_history_page.dart';
import '../ui/layout/page_shell.dart';
import '../pages/creditform/personal_form_menu.dart';
import '../pages/creditjob/personal_job_menu.dart';
import 'credit_core_site_actions.dart';

enum _MenuSection { creditForm, creditJob, creditCalc, gestione }

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
  static const _calcColor = Color(0xFF00B0FF);
  static const _areaColor = Color(0xFF1565C0);

  static final _formLight = _formColor.withValues(alpha: 0.15);
  static final _jobLight = _jobColor.withValues(alpha: 0.15);
  static final _calcLight = _calcColor.withValues(alpha: 0.15);

  _MenuSection? _openSection;
  String? _userType;
  String? _workRole;
  bool _blockedContext = false;
  bool _isBkAdmin = false;
  bool _loading = true;
  Map<String, String> _gestioneViewedDays = const {};

  @override
  void initState() {
    super.initState();
    _loadUserContext();
    _loadGestioneViewedDays();
    GestioneMenuBadgeService.changes.addListener(_onGestioneBadgeChanged);
  }

  @override
  void dispose() {
    GestioneMenuBadgeService.changes.removeListener(_onGestioneBadgeChanged);
    super.dispose();
  }

  void _onGestioneBadgeChanged() {
    _loadGestioneViewedDays();
  }

  Future<void> _loadGestioneViewedDays() async {
    final days = await ReadStateService.getGestioneMenuViewedDays();
    if (!mounted) return;
    setState(() => _gestioneViewedDays = days);
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
    final sectionName = switch (section) {
      _MenuSection.creditForm => MaintenanceService.creditForm,
      _MenuSection.creditJob => MaintenanceService.creditJob,
      _MenuSection.creditCalc => MaintenanceService.creditCalc,
      _ => MaintenanceService.creditCalc,
    };
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

  Widget _menuRedDot() {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(right: 8),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCalcAreaSectionTitle(
    String label,
    _MenuSection section,
    Map<String, dynamic>? maintenanceData, {
    bool showBadge = false,
  }) {
    final isOpen = _openSection == section;
    final blocked = MaintenanceService.isSectionBlocked(
      maintenanceData,
      MaintenanceService.creditCalc,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: _areaColor,
        ),
      ),
      trailing: blocked
          ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBadge) _menuRedDot(),
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

  void _openCalcPage(Widget page) {
    _closeAnd(() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      );
    });
  }

  void _openGestionePage(Widget page, GestioneMenuBadgeKey? badgeKey) {
    _closeAnd(() {
      if (badgeKey != null) {
        GestioneMenuBadgeService.markViewed(badgeKey);
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      );
    });
  }

  Widget _buildGestioneSubItem(
    String title,
    VoidCallback onTap,
    Map<String, dynamic>? maintenanceData, {
    bool showBadge = false,
  }) {
    final blocked = MaintenanceService.isSectionBlocked(
      maintenanceData,
      MaintenanceService.creditCalc,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '- $title',
              style: TextStyle(color: blocked ? Colors.black38 : Colors.black87),
            ),
          ),
          if (showBadge) _menuRedDot(),
        ],
      ),
      tileColor: _areaColor.withValues(alpha: 0.08),
      onTap: blocked ? _showMaintenanceSnackBar : onTap,
    );
  }

  Widget _buildCreditCalcMenuSection(Map<String, dynamic>? maintenanceData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildExpandableSectionTitle(
          BrandedPageProject.calc,
          _MenuSection.creditCalc,
          maintenanceData,
        ),
        if (_openSection == _MenuSection.creditCalc) ...[
          _buildSubMenuItem(
            'Creditori',
            () => _openCalcPage(const CreditorsPage()),
            _calcColor,
            _calcLight,
            maintenanceData,
            MaintenanceService.creditCalc,
          ),
          _buildSubMenuItem(
            'Sviluppa',
            () => _openCalcPage(const DevelopPage()),
            _calcColor,
            _calcLight,
            maintenanceData,
            MaintenanceService.creditCalc,
          ),
          _buildSubMenuItem(
            'Provvigioni',
            () => _openCalcPage(const CommissionsPage()),
            _calcColor,
            _calcLight,
            maintenanceData,
            MaintenanceService.creditCalc,
          ),
          _buildSubMenuItem(
            'Riscontro backoffice',
            () => _openCalcPage(const BackofficePendingPlansPage()),
            _calcColor,
            _calcLight,
            maintenanceData,
            MaintenanceService.creditCalc,
          ),
          _buildSubMenuItem(
            'Monitoraggio rata',
            () => _openCalcPage(
              const InstallmentMonitorPage(personalArea: true),
            ),
            _calcColor,
            _calcLight,
            maintenanceData,
            MaintenanceService.creditCalc,
          ),
        ],
      ],
    );
  }

  Widget _buildGestioneMenuSection(Map<String, dynamic>? maintenanceData) {
    final today = DateTime.now();

    return StreamBuilder<List<FieldVisit>>(
      stream: FieldVisitService.watchForDay(today),
      builder: (context, visitsSnap) {
        return StreamBuilder<List<FieldActivity>>(
          stream: FieldActivityService.watchAll(),
          builder: (context, activitiesSnap) {
            return StreamBuilder<List<FieldReminder>>(
              stream: FieldReminderService.watchUpcoming(),
              builder: (context, remindersSnap) {
                final visits = visitsSnap.data ?? const [];
                final activities = activitiesSnap.data ?? const [];
                final reminders = remindersSnap.data ?? const [];

                bool badgeFor(GestioneMenuBadgeKey key) =>
                    GestioneMenuBadgeService.shouldShowBadge(
                      key,
                      viewedDays: _gestioneViewedDays,
                      visits: visits,
                      activities: activities,
                      reminders: reminders,
                      today: today,
                    );

                final sectionBadge =
                    GestioneMenuBadgeService.shouldShowGestioneSectionBadge(
                  viewedDays: _gestioneViewedDays,
                  visits: visits,
                  activities: activities,
                  reminders: reminders,
                  today: today,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCalcAreaSectionTitle(
                      'Gestione',
                      _MenuSection.gestione,
                      maintenanceData,
                      showBadge: sectionBadge,
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: ItineraryDaySummaryCard(),
                    ),
                    if (_openSection == _MenuSection.gestione) ...[
                      _buildGestioneSubItem(
                        'Appuntamenti',
                        () => _openGestionePage(
                          const PracticeAgendaPage(
                            pageTitle: 'Appuntamenti',
                            personalArea: true,
                          ),
                          GestioneMenuBadgeKey.appointments,
                        ),
                        maintenanceData,
                        showBadge: badgeFor(GestioneMenuBadgeKey.appointments),
                      ),
                      _buildGestioneSubItem(
                        'Attività',
                        () => _openGestionePage(
                          const ActivitiesPage(personalArea: true),
                          GestioneMenuBadgeKey.activities,
                        ),
                        maintenanceData,
                        showBadge: badgeFor(GestioneMenuBadgeKey.activities),
                      ),
                      _buildGestioneSubItem(
                        'Promemoria',
                        () => _openGestionePage(
                          const RemindersPage(personalArea: true),
                          GestioneMenuBadgeKey.reminders,
                        ),
                        maintenanceData,
                        showBadge: badgeFor(GestioneMenuBadgeKey.reminders),
                      ),
                      _buildGestioneSubItem(
                        'Pianificazione',
                        () => _openGestionePage(
                          const TerritoryMapPage(
                            pageTitle: 'Pianificazione',
                            personalArea: true,
                          ),
                          null,
                        ),
                        maintenanceData,
                      ),
                      _buildGestioneSubItem(
                        'Storico visite',
                        () => _openGestionePage(
                          const VisitHistoryPage(personalArea: true),
                          null,
                        ),
                        maintenanceData,
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
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
        final calcBlocked = MaintenanceService.isSectionBlocked(
          maintenanceData,
          MaintenanceService.creditCalc,
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
                icon: Icons.person_outline,
                title: PersonalAreaMenuItem.myData.title,
                iconColor: _areaColor,
                onTap: () => _closeAndArea(PersonalAreaMenuItem.myData),
              ),
              if (!isWork)
                _item(
                  icon: Icons.card_membership_outlined,
                  title: PersonalAreaMenuItem.subscription.title,
                  iconColor: _areaColor,
                  onTap: () =>
                      _closeAndArea(PersonalAreaMenuItem.subscription),
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
                icon: Icons.record_voice_over_outlined,
                title: 'Contestazioni warm-up',
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
                icon: Icons.balance_outlined,
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
