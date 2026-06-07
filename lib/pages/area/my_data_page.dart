// ignore_for_file: deprecated_member_use
// -----------------------------------------------------------------------------
// CONFIG / IMPORT / WIDGET ROOT
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import '../../core/dimensions.dart';
import '../../core/work_code_helpers.dart';
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
    _loadUserData();
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
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    email = user.email ?? '';
    userUid = user.uid;

    try {
      // 🔹 STEP 1: leggo USERS
      final userDoc =
      await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        setState(() => _loading = false);
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
      });
    } catch (e) {
      debugPrint('❌ Errore caricamento dati utente: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
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
    final isMobile = Dimensions.isTablet(context);

    if (_loading || userType == null) {
      return const PersonalAreaShell(
        pageTitle: 'I miei dati',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool isCompany = userType == 'company';
    final bool isWork = userType == 'work';
    final bool canDeleteCompany = isCompany && hasLinkedWorkUsers == false;

    return PersonalAreaShell(
      pageTitle: 'I miei dati',
      body: SingleChildScrollView(
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCompany
                          ? Icons.business_outlined
                          : Icons.person_outline,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isCompany ? 'Dati azienda' : 'Profilo',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Gestisci dati profilo e sicurezza.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // ---------------- UTENTE ----------------
                if (!isCompany) ...[
                  _kv('Nome', firstName.isNotEmpty ? firstName : '—', isMobile),
                  _kv('Cognome',
                      lastName.isNotEmpty ? lastName : '—', isMobile),
                  _kv('Email', email.isNotEmpty ? email : '—', isMobile),
                  _kv('Data registrazione', registrationDateTime, isMobile),
                  const SizedBox(height: 8),
                  if (isWork)
                    _kv(
                      'Codice utente',
                      workUserCode.isNotEmpty ? workUserCode : '—',
                      isMobile,
                    )
                  else ...[
                    if (userCode.isNotEmpty)
                      _kv('Codice progressi', userCode, isMobile),
                    _kv('Codice piattaforma', userUid, isMobile),
                  ],
                ],

                // ---------------- AZIENDA ----------------
                if (isCompany) ...[
                  _kv('Ragione sociale',
                      companyName.isNotEmpty ? companyName : '—', isMobile),
                  _kv('Partita IVA', piva.isNotEmpty ? piva : '—', isMobile),
                  _kv('Email azienda',
                      companyEmail.isNotEmpty ? companyEmail : '—', isMobile),
                  _kv('Telefono', phone.isNotEmpty ? phone : '—', isMobile),
                  _kv('Indirizzo',
                      address.isNotEmpty ? address : '—', isMobile),
                  _kv('Sito web',
                      website.isNotEmpty ? website : '—', isMobile),
                  _kv('Data registrazione', registrationDateTime, isMobile),
                  const Divider(height: 32),
                  _kv('Referente',
                      referencePerson.isNotEmpty ? referencePerson : '—',
                      isMobile),
                  _kv('Ruolo referente',
                      referenceRole.isNotEmpty ? referenceRole : '—',
                      isMobile),
                  const Divider(height: 32),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: isMobile ? 140 : 200,
                          child: const SelectableText(
                            'Codice aziendale',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            companyCode.isNotEmpty ? companyCode : '—',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: isMobile ? 140 : 200,
                          child: const SelectableText(
                            'Codice collaboratori',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            collaboratorsCode.isNotEmpty
                                ? collaboratorsCode
                                : '—',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: isMobile ? 140 : 200,
                          child: const SelectableText(
                            'Codice supervisori',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            supervisorsCode.isNotEmpty
                                ? supervisorsCode
                                : '—',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  SelectableText(
                    'Accesso operatori e TL:\n'
                        'https://creditplanet-work.netlify.app',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openEditDialog(context),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Modifica dati'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openPasswordDialog(context),
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Cambia password'),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => _confirmDelete(context),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          isCompany && !canDeleteCompany
                              ? 'Disattiva account (ci sono collegamenti)'
                              : 'Elimina account',
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openEditDialog(context),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Modifica dati'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => _openPasswordDialog(context),
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Cambia password'),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: () => _confirmDelete(context),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          isCompany && !canDeleteCompany
                              ? 'Disattiva account (ci sono collegamenti)'
                              : 'Elimina account',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
      ),
    );
  }


// -----------------------------------------------------------------------------
// UI HELPERS
// -----------------------------------------------------------------------------
  Widget _kv(String k, String v, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 140 : 200,
            child: SelectableText(
              k,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: SelectableText(v),
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

                  await _auth.signOut();
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