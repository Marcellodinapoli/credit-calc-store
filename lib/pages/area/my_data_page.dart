// ignore_for_file: deprecated_member_use
// -----------------------------------------------------------------------------
// CONFIG / IMPORT / WIDGET ROOT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:credit_calc_core/credit_calc_core.dart'
    show
        UserSubscriptionService,
        UserSubscriptionSnapshot,
        companyDedicatedSubscriptionPlan,
        isCompanySubscriptionAudience,
        subscriptionPlanLabel,
        subscriptionPlansForType,
        LimitsResetCouponSection,
        appFormTextField,
        appFormFieldDecoration;
import '../../session/credit_core_session_runtime.dart';
import '../../core/dimensions.dart';
import '../../core/theme/app_card_theme.dart';
import '../../core/theme/project_colors.dart';
import '../../core/work_code_helpers.dart';
import 'personal_area_menu.dart';
import 'personal_area_shell.dart';

class MyDataPage extends StatefulWidget {
  const MyDataPage({super.key});

  @override
  State<MyDataPage> createState() => _MyDataPageState();
}

class _MyDataPageState extends State<MyDataPage> {

// -----------------------------------------------------------------------------
// STATE
// -----------------------------------------------------------------------------
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  bool _loading = true;
  String? _loadError;
  StreamSubscription<User?>? _authSub;

// DATI UTENTE
  String firstName = '';
  String lastName = '';
  String email = '';
  String userCode = '';
  String workUserCode = '';
  String userUid = '';

// TIPO UTENTE
  String? userType;

// DATI AZIENDA
  String companyName = '';
  String piva = '';
  String companyEmail = '';
  String phone = '';
  String address = '';
  String website = '';

// REFERENTE
  String referencePerson = '';
  String referenceRole = '';

// CODICI
  String companyCode = '';
  String collaboratorsCode = '';
  String supervisorsCode = '';

// DATA REGISTRAZIONE (data + ora formattata)
  String registrationDateTime = '—';

// TIMESTAMP GREZZO FIRESTORE
  DateTime? createdAt;

// -----------------------------------------------------------------------------
// LIFECYCLE
// -----------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _authSub = _auth.authStateChanges().listen((user) {
      if (!mounted || user == null) return;
      if (_loading || userType != null) return;
      unawaited(_loadUserData());
    });
    unawaited(_loadUserData());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

// -----------------------------------------------------------------------------
// SERVICES / HELPERS – DATA
// -----------------------------------------------------------------------------
  bool hasLinkedWorkUsers = false;

  Future<String> _resolveWorkUserCode(
    Map<String, dynamic> userData,
    String companyId,
  ) async {
    final stored = (userData['workCode'] ?? '').toString().trim();
    if (WorkCodeHelpers.looksLikeWorkCode(stored)) return stored;

    final workRole = WorkCodeHelpers.normalizeRoleValue(userData['workRole']);
    if (workRole.isEmpty) return stored;

    final suffix = workRole == 'supervisor' ? 'SUP' : 'COL';
    final companyCodeField = (userData['companyCode'] ?? '').toString().trim();

    if (companyCodeField.isNotEmpty) {
      final upper = companyCodeField.toUpperCase();
      if (WorkCodeHelpers.looksLikeWorkCode(upper)) return upper;

      final built = '$companyCodeField-$suffix';
      if (WorkCodeHelpers.looksLikeWorkCode(built)) return built;
    }

    if (companyId.isEmpty) return stored;

    try {
      final snap = await _firestore
          .collection('work_codes')
          .where('companyId', isEqualTo: companyId)
          .where('role', isEqualTo: workRole)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return snap.docs.first.id;
    } catch (e) {
      debugPrint('⚠️ Errore risoluzione codice utente work: $e');
    }

    return stored;
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Sessione non disponibile. Accedi di nuovo.';
      });
      return;
    }

    email = user.email ?? '';
    userUid = user.uid;

    try {
      // 🔹 STEP 1: leggo USERS
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 15));

      if (!userDoc.exists) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = 'Profilo utente non trovato.';
        });
        return;
      }

      final userData = userDoc.data()!;

      userType = userData['type'] ?? 'public';
      userCode = (userData['userCode'] ?? '').toString().trim();

      // 🔹 STEP 2: prendo companyId
      final companyId =
      (userData['companyId'] ?? user.uid).toString();

      // 🔹 STEP 3: leggo COMPANIES
      final companyDoc = await _firestore
          .collection('companies')
          .doc(companyId)
          .get();

      Map<String, dynamic> companyData = {};
      if (companyDoc.exists) {
        companyData = companyDoc.data()!;
      }

      String resolvedWorkUserCode = '';
      if (userType == 'work') {
        resolvedWorkUserCode =
            await _resolveWorkUserCode(userData, companyId);
      }

      // 🔹 STEP 4: leggo WORK_CODES
      String collCode = '';
      String supCode = '';

      if (userCode.isNotEmpty) {
        try {
          final codesQuery = await _firestore
              .collection('work_codes')
              .where('companyCode', isEqualTo: userCode)
              .get();

          for (final doc in codesQuery.docs) {
            final d = doc.data();

            if (d['role'] == 'collaborator') {
              collCode = doc.id;
            }

            if (d['role'] == 'supervisor') {
              supCode = doc.id;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Errore lettura work_codes: $e');
        }
      }

      // DATA REGISTRAZIONE
      DateTime? created;
      if (companyData['createdAt'] != null &&
          companyData['createdAt'] is Timestamp) {
        created =
            (companyData['createdAt'] as Timestamp).toDate().toLocal();
      }

      // 🔎 VERIFICA COLLEGAMENTI WORK
      bool linkedUsers = false;

      if (userType == 'company' && userCode.isNotEmpty) {
        try {
          final q = await _firestore
              .collection('users')
              .where('type', isEqualTo: 'work')
              .where('companyCode', isEqualTo: userCode)
              .limit(1)
              .get();

          linkedUsers = q.docs.isNotEmpty;
        } catch (e) {
          debugPrint('⚠️ Errore verifica collegamenti work: $e');
        }
      }

      if (!mounted) return;

      setState(() {
        userType = userData['type'] ?? 'public';
        // 🔹 UTENTE BASE
        firstName = (userData['name'] ?? '').toString().trim();
        lastName = (userData['surname'] ?? '').toString().trim();

        // 🔹 DATI AZIENDA
        companyName =
            (companyData['companyName'] ?? '').toString().trim();

        piva = (companyData['piva'] ?? '').toString().trim();

        companyEmail =
            (companyData['email'] ?? email).toString().trim();

        phone = (companyData['phone'] ?? '').toString().trim();
        address = (companyData['address'] ?? '').toString().trim();
        website = (companyData['website'] ?? '').toString().trim();

        referencePerson =
            (companyData['referencePerson'] ?? '').toString().trim();

        referenceRole =
            (companyData['referenceRole'] ?? '').toString().trim();

        // 🔹 CODICI
        companyCode =
            (companyData['companyCode'] ?? userCode).toString().trim();

        collaboratorsCode = collCode;
        supervisorsCode = supCode;
        workUserCode = resolvedWorkUserCode;

        hasLinkedWorkUsers = linkedUsers;

        createdAt = created;

        registrationDateTime = createdAt != null
            ? '${createdAt!.day.toString().padLeft(2, '0')}/'
            '${createdAt!.month.toString().padLeft(2, '0')}/'
            '${createdAt!.year} '
            '${createdAt!.hour.toString().padLeft(2, '0')}:'
            '${createdAt!.minute.toString().padLeft(2, '0')}'
            : '—';

        _loading = false;
        _loadError = null;
      });
    } on TimeoutException {
      debugPrint('❌ Timeout caricamento dati utente');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Caricamento troppo lento. Riprova.';
      });
    } catch (e) {
      debugPrint('❌ Errore caricamento dati utente: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadError = 'Impossibile caricare i dati. Riprova.';
      });
    }
  }

  Future<void> _deleteAllUserData(User user) async {
    final uid = user.uid;

    final collections = [
      'progress',
      'quizResults',
      'roleplayResults',
      'listeningResults',
    ];

    for (final coll in collections) {
      final query = await _firestore
          .collection(coll)
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
      }
    }

    try {
      final supportQuery = await _firestore
          .collection('support')
          .where('userId', isEqualTo: uid)
          .get();

      for (final doc in supportQuery.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('❌ Errore cancellazione support: $e');
    }

    try {
      await _firestore.collection('roleplay_progress').doc(uid).delete();
    } catch (e) {
      debugPrint('❌ Errore cancellazione roleplay_progress: $e');
    }

    try {
      final upDoc =
      _firestore.collection('userProgress').doc(uid);

      final snap = await upDoc.get();

      if (snap.exists) {
        final courses =
        await upDoc.collection('courses').get();

        for (final c in courses.docs) {
          await c.reference.delete();
        }

        await upDoc.delete();
      }
    } catch (e) {
      debugPrint('❌ Errore cancellazione userProgress: $e');
    }

    try {
      final ref =
      _storage.ref().child('user_uploads/$uid');

      final list = await ref.listAll();

      for (final item in list.items) {
        await item.delete();
      }
    } catch (e) {
      debugPrint('⚠️ Errore eliminazione Storage: $e');
    }

    await _firestore.collection('users').doc(uid).delete();
  }
// -----------------------------------------------------------------------------
// BUILD
// -----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isMobile = Dimensions.isPhone(context);
    final pagePadding = Dimensions.pagePaddingInsetsFor(context);
    final contentWidth = (MediaQuery.sizeOf(context).width - pagePadding.horizontal)
        .clamp(0.0, Dimensions.shellContentMaxWidthFor(context));

    if (_loading) {
      return const PersonalAreaShell(
        pageTitle: 'I miei dati',
        activeMenuItem: PersonalAreaMenuItem.myData,
        backToCreditCalcHome: true,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userType == null) {
      return PersonalAreaShell(
        pageTitle: 'I miei dati',
        activeMenuItem: PersonalAreaMenuItem.myData,
        backToCreditCalcHome: true,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  _loadError ?? 'Impossibile caricare i dati.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadUserData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isCompany = userType == 'company';
    final bool isWork = userType == 'work';
    final bool canDeleteCompany = isCompany && hasLinkedWorkUsers == false;

    return PersonalAreaShell(
      pageTitle: 'I miei dati',
      activeMenuItem: PersonalAreaMenuItem.myData,
      backToCreditCalcHome: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: 24 + Dimensions.resolvedBottomInset(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Gestisci piano, dati personali e sicurezza dell\'account.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileSections(
              context: context,
              isCompany: isCompany,
              isWork: isWork,
              isMobile: isMobile,
              contentWidth: contentWidth,
            ),
            if (userType == 'public') ...[
            const SizedBox(height: 28),
            const _SectionHeading(
              title: 'Coupon limiti',
              subtitle:
                  'Inserisci un coupon creato dal backoffice per azzerare '
                  'i contatori mensili del tuo piano.',
            ),
            const SizedBox(height: 12),
            const LimitsResetCouponSection(),
          ],
          const SizedBox(height: 28),
          const _SectionHeading(
            title: 'Sicurezza e account',
            subtitle: 'Aggiorna i dati, la password o gestisci l\'account.',
          ),
          const SizedBox(height: 12),
          _ProfileDataCard(
            isMobile: isMobile,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _openEditDialog(context),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          label: const Text('Modifica dati'),
                          style: FilledButton.styleFrom(
                            backgroundColor: ProjectColors.area,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => _openPasswordDialog(context),
                          icon: const Icon(Icons.lock_reset, size: 20),
                          label: const Text('Cambia password'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ProjectColors.area,
                            side: const BorderSide(color: ProjectColors.area),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _confirmDelete(context),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red.shade700,
                          ),
                          label: Text(
                            isCompany && !canDeleteCompany
                                ? 'Disattiva account (ci sono collegamenti)'
                                : 'Elimina account',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _openEditDialog(context),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          label: const Text('Modifica dati'),
                          style: FilledButton.styleFrom(
                            backgroundColor: ProjectColors.area,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openPasswordDialog(context),
                          icon: const Icon(Icons.lock_reset, size: 20),
                          label: const Text('Cambia password'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ProjectColors.area,
                            side: const BorderSide(color: ProjectColors.area),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _confirmDelete(context),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red.shade700,
                          ),
                          label: Text(
                            isCompany && !canDeleteCompany
                                ? 'Disattiva account (ci sono collegamenti)'
                                : 'Elimina account',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          ],
        ),
      ),
    );
  }


// -----------------------------------------------------------------------------
// UI HELPERS
// -----------------------------------------------------------------------------
  Widget _buildProfileSections({
    required BuildContext context,
    required bool isCompany,
    required bool isWork,
    required bool isMobile,
    required double contentWidth,
  }) {
    final personalHeading = _SectionHeading(
      title: isCompany ? 'Anagrafica azienda' : 'Dati personali',
      subtitle: isCompany
          ? 'Informazioni registrate per il workspace aziendale.'
          : 'Informazioni del tuo account CreditCalc.',
    );
    final personalCard = _buildPersonalDataCard(isCompany, isWork, isMobile);

    if (isWork) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          personalHeading,
          const SizedBox(height: 12),
          personalCard,
        ],
      );
    }

    final sideBySide = contentWidth >= 900;
    if (!sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PlanSummaryCard(),
          const SizedBox(height: 28),
          personalHeading,
          const SizedBox(height: 12),
          personalCard,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: _SectionHeading(
                title: 'Il tuo piano',
                subtitle: 'Piano attivo, coupon e gestione abbonamento.',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: personalHeading),
          ],
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(
                child: _PlanSummaryCard(showHeader: false, stretch: true),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildPersonalDataCard(
                  isCompany,
                  isWork,
                  isMobile,
                  stretch: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalDataCard(
    bool isCompany,
    bool isWork,
    bool isMobile, {
    bool stretch = false,
  }) {
    return _ProfileDataCard(
      isMobile: isMobile,
      stretch: stretch,
      children: [
        if (!isCompany) ...[
          _profileRow(
            'Nome',
            firstName.isNotEmpty ? firstName : '—',
            isMobile,
          ),
          _profileRow(
            'Cognome',
            lastName.isNotEmpty ? lastName : '—',
            isMobile,
          ),
          _profileRow(
            'Email',
            email.isNotEmpty ? email : '—',
            isMobile,
          ),
          _profileRow(
            'Data registrazione',
            registrationDateTime,
            isMobile,
          ),
          if (isWork)
            _profileRow(
              'Codice utente',
              workUserCode.isNotEmpty ? workUserCode : '—',
              isMobile,
            )
          else ...[
            if (userCode.isNotEmpty)
              _profileRow(
                'Codice progressi',
                userCode,
                isMobile,
              ),
            _profileRow(
              'Codice piattaforma',
              userUid,
              isMobile,
              monospace: true,
            ),
          ],
        ],
        if (isCompany) ...[
          _profileRow(
            'Ragione sociale',
            companyName.isNotEmpty ? companyName : '—',
            isMobile,
          ),
          _profileRow(
            'Partita IVA',
            piva.isNotEmpty ? piva : '—',
            isMobile,
          ),
          _profileRow(
            'Email azienda',
            companyEmail.isNotEmpty ? companyEmail : '—',
            isMobile,
          ),
          _profileRow(
            'Telefono',
            phone.isNotEmpty ? phone : '—',
            isMobile,
          ),
          _profileRow(
            'Indirizzo',
            address.isNotEmpty ? address : '—',
            isMobile,
          ),
          _profileRow(
            'Sito web',
            website.isNotEmpty ? website : '—',
            isMobile,
          ),
          _profileRow(
            'Data registrazione',
            registrationDateTime,
            isMobile,
          ),
          _profileRow(
            'Referente',
            referencePerson.isNotEmpty ? referencePerson : '—',
            isMobile,
          ),
          _profileRow(
            'Ruolo referente',
            referenceRole.isNotEmpty ? referenceRole : '—',
            isMobile,
          ),
          _profileRow(
            'Codice aziendale',
            companyCode.isNotEmpty ? companyCode : '—',
            isMobile,
            monospace: true,
          ),
          _profileRow(
            'Codice collaboratori',
            collaboratorsCode.isNotEmpty ? collaboratorsCode : '—',
            isMobile,
            monospace: true,
          ),
          _profileRow(
            'Codice supervisori',
            supervisorsCode.isNotEmpty ? supervisorsCode : '—',
            isMobile,
            monospace: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SelectableText(
              'Accesso operatori e TL:\n'
              'https://creditplanet-work.netlify.app',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ProjectColors.area,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _profileRow(
    String label,
    String value,
    bool isMobile, {
    bool monospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 128 : 168,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.02,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                fontFamily: monospace ? 'monospace' : null,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tf(String label, TextEditingController controller) {
    return appFormTextField(
      label: label,
      controller: controller,
      padding: const EdgeInsets.only(bottom: 8),
    );
  }

// -----------------------------------------------------------------------------
// ACTIONS – UI / DIALOG
// -----------------------------------------------------------------------------
  void _openEditDialog(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return;

    final firstCtrl = TextEditingController(text: firstName);
    final lastCtrl = TextEditingController(text: lastName);
    final companyNameCtrl = TextEditingController(text: companyName);
    final pivaCtrl = TextEditingController(text: piva);
    final phoneCtrl = TextEditingController(text: phone);
    final addressCtrl = TextEditingController(text: address);
    final websiteCtrl = TextEditingController(text: website);
    final referencePersonCtrl =
    TextEditingController(text: referencePerson);
    final referenceRoleCtrl =
    TextEditingController(text: referenceRole);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifica dati'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width < 460
                ? double.infinity
                : 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: userType == 'company'
                  ? [
                TextField(
                  controller: companyNameCtrl,
                  enabled: false,
                  decoration: appFormFieldDecoration('Ragione sociale'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 12),
                  child: Text(
                    'Per modificare questo dato è necessario contattare il supporto dall’area dedicata.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: pivaCtrl,
                  enabled: false,
                  decoration: appFormFieldDecoration('Partita IVA'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 12),
                  child: Text(
                    'Per modificare questo dato è necessario contattare il supporto dall’area dedicata.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                _tf('Telefono', phoneCtrl),
                _tf('Indirizzo', addressCtrl),
                _tf('Sito web', websiteCtrl),
                _tf('Referente', referencePersonCtrl),
                _tf('Ruolo referente', referenceRoleCtrl),
              ]
                  : [
                _tf('Nome', firstCtrl),
                _tf('Cognome', lastCtrl),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              final Map<String, dynamic> updateData = {};

              if (userType == 'company') {
                updateData.addAll({
                  'phone': phoneCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'website': websiteCtrl.text.trim(),
                  'referencePerson': referencePersonCtrl.text.trim(),
                  'referenceRole': referenceRoleCtrl.text.trim(),
                });
              } else {
                updateData.addAll({
                  'name': firstCtrl.text.trim(),
                  'surname': lastCtrl.text.trim(),
                });
              }

              await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .update(updateData);

              await _loadUserData();

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _openPasswordDialog(BuildContext context) {
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cambia password'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: SizedBox(
              width: MediaQuery.of(context).size.width < 460
                  ? double.infinity
                  : 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: newCtrl,
                    obscureText: true,
                    decoration: appFormFieldDecoration('Nuova password'),
                    validator: (v) =>
                    (v == null || v.length < 6)
                        ? 'Almeno 6 caratteri'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: confCtrl,
                    obscureText: true,
                    decoration: appFormFieldDecoration('Conferma password'),
                    validator: (v) =>
                    (v != newCtrl.text)
                        ? 'Le password non coincidono'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await _auth.currentUser!
                    .updatePassword(newCtrl.text.trim());
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password aggiornata')),
                );
              } catch (e) {
                debugPrint('❌ Errore cambio password: $e');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                      Text('Errore durante l\'aggiornamento')),
                );
              }
            },
            child: const Text('Aggiorna'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final linkedUsers = await _firestore
        .collection('users')
        .where('type', isEqualTo: 'work')
        .where('companyId', isEqualTo: user.uid)
        .limit(1)
        .get();

    final hasLinks = linkedUsers.docs.isNotEmpty;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(hasLinks ? 'Disattiva account' : 'Elimina account'),
        content: Text(
          hasLinks
              ? 'Sono presenti collaboratori o supervisor collegati. '
              'L’account verrà disattivato ma i dati non saranno eliminati.'
              : 'Sei sicuro di voler eliminare il tuo account e tutti i dati associati? '
              'Questa azione è irreversibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                if (hasLinks) {
                  await _firestore
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'status': 'disabled',
                    'disabledAt': FieldValue.serverTimestamp(),
                  });

                  await CreditCoreSessionRuntime.signOutWithSessionRelease();
                } else {
                  await _deleteAllUserData(user);
                  await user.delete();
                }

                await SharedPreferences.getInstance().then((p) => p.clear());

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        hasLinks
                            ? 'Account disattivato correttamente'
                            : 'Account eliminato con successo',
                      ),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('❌ Errore operazione account: $e');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                      Text('Errore durante l\'operazione')),
                );
              }
            },
            child: Text(hasLinks ? 'Disattiva' : 'Conferma'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _ProfileDataCard extends StatelessWidget {
  const _ProfileDataCard({
    required this.isMobile,
    this.children,
    this.child,
    this.stretch = false,
  });

  final bool isMobile;
  final List<Widget>? children;
  final Widget? child;
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: AppCardTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: child ??
            Column(
              children: [
                for (var i = 0; i < children!.length; i++) ...[
                  children![i],
                  if (i < children!.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.shade100,
                      indent: 20,
                      endIndent: 20,
                    ),
                ],
              ],
            ),
      ),
    );

    if (!stretch) return card;
    return SizedBox(width: double.infinity, height: double.infinity, child: card);
  }
}

String _planTierLabel(String planId) {
  return switch (planId) {
    'enterprise' => 'ENTERPRISE',
    'plus' => 'PLUS',
    _ => 'FREE',
  };
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    this.showHeader = true,
    this.stretch = false,
  });

  final bool showHeader;
  final bool stretch;

  void _openPlanPage(BuildContext context) {
    PersonalAreaMenuItem.subscription.open(context);
  }

  static String _formatCouponDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserSubscriptionSnapshot>(
      stream: UserSubscriptionService.watchCurrent(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final sub = snapshot.data!;
        final isCompany = isCompanySubscriptionAudience(sub.registerType);
        final plan = isCompany
            ? companyDedicatedSubscriptionPlan
            : sub.planOption(subscriptionPlansForType(sub.registerType));
        final planName =
            plan?.name ?? subscriptionPlanLabel(sub.planId);
        final tierLabel = isCompany
            ? 'AZIENDA'
            : _planTierLabel(sub.planId);
        final expired = sub.isCouponLimitsEffectExpired;

        final cardBody = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ProjectColors.area.withValues(alpha: 0.08),
                const Color(0xFFF8FAFC),
              ],
            ),
            border: Border.all(
              color: ProjectColors.area.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: ProjectColors.area.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  color: ProjectColors.area,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:
                          stretch ? MainAxisSize.max : MainAxisSize.min,
                      children: [
                        if (showHeader)
                          Row(
                            children: [
                              const Text(
                                'Il tuo piano',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.06,
                                  color: ProjectColors.area,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ProjectColors.area
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  tierLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.08,
                                    color: ProjectColors.area,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    ProjectColors.area.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tierLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.08,
                                  color: ProjectColors.area,
                                ),
                              ),
                            ),
                          ),
                        SizedBox(height: showHeader ? 12 : 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              planName,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (plan != null) ...[
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  plan.price,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (plan != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            plan.description,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: expired
                                ? const Color(0xFFFFF7ED)
                                : Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: expired
                                  ? const Color(0xFFFDBA74)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Text(
                            sub.statusLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: expired
                                  ? Colors.orange.shade900
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ),
                        if (sub.hasCoupon || sub.lifetimeAccess) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: expired
                                  ? const Color(0xFFFFF7ED)
                                  : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: expired
                                    ? const Color(0xFFFDBA74)
                                    : const Color(0xFF86EFAC),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  expired
                                      ? Icons.event_busy_outlined
                                      : Icons.verified_outlined,
                                  size: 20,
                                  color: expired
                                      ? Colors.orange.shade800
                                      : Colors.green.shade700,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        expired
                                            ? 'Coupon applicato (effetto scaduto)'
                                            : 'Coupon applicato',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (sub.hasCoupon) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Codice: ${sub.couponCode}',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                      if (sub.couponAppliedAt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Data inserimento: '
                                          '${_formatCouponDate(sub.couponAppliedAt!)}',
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            height: 1.4,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        expired
                                            ? 'Effetto limiti terminato il '
                                                '${_formatCouponDate(sub.limitsEffectExpiresAt!)}. '
                                                'Sono attivi i limiti del piano Gratis.'
                                            : sub.limitsEffectExpiresAt != null
                                                ? 'Data effetto limiti: '
                                                    '${_formatCouponDate(sub.limitsEffectExpiresAt!)}'
                                                : sub.lifetimeAccess
                                                    ? 'Accesso lifetime attivo senza abbonamento ricorrente.'
                                                    : 'Coupon registrato in fase di iscrizione.',
                                        style: TextStyle(
                                          color: expired
                                              ? Colors.orange.shade900
                                              : Colors.grey.shade800,
                                          height: 1.4,
                                          fontSize: 13,
                                          fontWeight: expired
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (stretch) const Spacer(),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _openPlanPage(context),
                          icon: const Icon(Icons.workspace_premium_outlined,
                              size: 18),
                          label: const Text('Gestisci piano e abbonamento'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ProjectColors.area,
                            side: const BorderSide(color: ProjectColors.area),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (!stretch) return cardBody;
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: cardBody,
        );
      },
    );
  }
}