import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../offline/services/connectivity_service.dart';
import '../services/biometric_service.dart';
import 'auth_form_validation.dart';
import 'registration_privacy_consents_page.dart';

abstract final class AppTheme {
  static const accent = Color(0xFF0A66C2);
  static const body = Color(0xFFE8E8E8);
}

class LoginPage extends StatefulWidget {
  /// Sblocco dopo riapertura app (sessione Firebase ancora attiva, non è un logout).
  final bool unlockMode;
  final Future<void> Function()? onUnlocked;

  const LoginPage({
    super.key,
    this.unlockMode = false,
    this.onUnlocked,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _biometricService = BiometricService();

  bool _isLogin = true;
  String? _registerType;
  bool _showBiometricButton = false;
  bool _hasSavedCredentials = false;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _companyName = TextEditingController();
  final _piva = TextEditingController();
  final _phone = TextEditingController();
  final _refPerson = TextEditingController();
  final _refRole = TextEditingController();
  final _website = TextEditingController();

  bool _obscure = true;
  bool _busy = false;

  String? _loginNotice;
  String? _emailError;
  String? _passwordError;
  String? _registerNotice;
  final Map<String, String> _registerFieldErrors = {};
  bool _privacyAccepted = false;

  @override
  void initState() {
    super.initState();
    if (widget.unlockMode) {
      _email.text = FirebaseAuth.instance.currentUser?.email ?? '';
    }
    _prepareBiometricUi();
  }

  Future<void> _prepareBiometricUi() async {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        break;
      default:
        return;
    }

    final savedEmail = await _secureStorage.read(key: 'credit_calc_email');
    final savedPassword = await _secureStorage.read(key: 'credit_calc_password');
    if (!mounted) return;

    final biometricAvailable = await _biometricService.isBiometricAvailable();

    if (!mounted) return;
    setState(() {
      _showBiometricButton = biometricAvailable;
      _hasSavedCredentials = savedEmail != null && savedPassword != null;
    });

    if (widget.unlockMode && biometricAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_signInBiometric());
      });
    }
  }

  Future<void> _saveCredentials(String email, String password) async {
    await _secureStorage.write(key: 'credit_calc_email', value: email);
    await _secureStorage.write(key: 'credit_calc_password', value: password);
  }

  Future<bool> _matchesSavedCredentials({
    required String email,
    required String password,
  }) async {
    final savedEmail = await _secureStorage.read(key: 'credit_calc_email');
    final savedPassword = await _secureStorage.read(key: 'credit_calc_password');
    if (savedPassword == null) return false;

    final current = FirebaseAuth.instance.currentUser;
    final emailOk = email.isEmpty ||
        email == savedEmail ||
        (current?.email != null && email == current!.email);
    return emailOk && password == savedPassword;
  }

  bool _isNetworkAuthError(FirebaseAuthException e) {
    return e.code == 'network-request-failed' ||
        e.code == 'too-many-requests';
  }

  Future<void> _signInBiometric() async {
    if (!widget.unlockMode && !_hasSavedCredentials) {
      if (!mounted) return;
      setState(() {
        _loginNotice =
            'Per usare la biometria, accedi prima una volta con email e password.';
      });
      return;
    }

    setState(() => _clearLoginFeedback());

    final authError = await _biometricService.authenticate();
    if (authError != null) {
      if (!mounted) return;
      setState(() => _loginNotice = authError);
      return;
    }

    if (widget.unlockMode) {
      await widget.onUnlocked?.call();
      return;
    }

    final email = await _secureStorage.read(key: 'credit_calc_email');
    final password = await _secureStorage.read(key: 'credit_calc_password');
    if (email == null || password == null) {
      if (!mounted) return;
      setState(() {
        _loginNotice =
            'Per usare la biometria, accedi prima una volta con email e password.';
        _hasSavedCredentials = false;
      });
      return;
    }

    final current = FirebaseAuth.instance.currentUser;
    if (current != null && current.email == email) {
      return;
    }

    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 8));
    } on FirebaseAuthException catch (e) {
      if (_isNetworkAuthError(e)) {
        final restored = FirebaseAuth.instance.currentUser;
        if (restored != null && restored.email == email) {
          return;
        }
      }
      final feedback = await AuthFormValidation.resolveLoginAuthFailure(e, email);
      if (!mounted) return;
      setState(() {
        _loginNotice = feedback.notice;
        _emailError = feedback.emailError;
        _passwordError = feedback.passwordError;
      });
    } on TimeoutException {
      if (FirebaseAuth.instance.currentUser?.email == email) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _loginNotice =
            'Connessione non disponibile. Se hai bloccato l\'app con «Esci» '
            'offline, usa la biometria su quella schermata oppure riapri l\'app.';
      });
    } catch (_) {
      if (FirebaseAuth.instance.currentUser?.email == email) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _loginNotice =
            'Accesso non disponibile senza connessione. Riprova quando la rete '
            'è attiva oppure sblocca l\'app con la biometria.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _name.dispose();
    _surname.dispose();
    _companyName.dispose();
    _piva.dispose();
    _phone.dispose();
    _refPerson.dispose();
    _refRole.dispose();
    _website.dispose();
    super.dispose();
  }

  void _clearLoginFeedback() {
    _loginNotice = null;
    _emailError = null;
    _passwordError = null;
  }

  void _clearRegisterFeedback() {
    _registerNotice = null;
    _registerFieldErrors.clear();
  }

  void _resetPrivacyAcceptance() {
    _privacyAccepted = false;
  }

  String? _regError(String key) => _registerFieldErrors[key];

  bool _isValidPiva(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11;
  }

  bool _validateRegisterForm({
    required String email,
    required String password,
    required String confirm,
  }) {
    final errors = <String, String>{};

    void requireField(String key, String value, {String? label}) {
      if (value.trim().isEmpty) {
        errors[key] = label != null ? '$label è obbligatorio.' : 'Campo obbligatorio.';
      }
    }

    if (_registerType == 'public') {
      requireField('name', _name.text, label: 'Il nome');
      requireField('surname', _surname.text, label: 'Il cognome');
    }

    if (_registerType == 'company') {
      requireField('companyName', _companyName.text, label: 'La ragione sociale');
      if (_piva.text.trim().isEmpty) {
        errors['piva'] = 'La Partita IVA è obbligatoria.';
      } else if (!_isValidPiva(_piva.text)) {
        errors['piva'] = 'La Partita IVA deve avere 11 cifre.';
      }
      requireField('phone', _phone.text, label: 'Il telefono');
      requireField('refPerson', _refPerson.text, label: 'La persona di riferimento');
      requireField('refRole', _refRole.text, label: 'Il ruolo');
      requireField('website', _website.text, label: 'Il sito internet');
    }

    if (email.isEmpty) {
      errors['email'] = 'L’email è obbligatoria.';
    } else if (!AuthFormValidation.looksLikeValidEmail(email)) {
      errors['email'] = 'L’indirizzo email non sembra corretto.';
    }

    if (password.isEmpty) {
      errors['password'] = 'La password è obbligatoria.';
    } else {
      final pwdMsg = AuthFormValidation.passwordRuleMessage(password);
      if (pwdMsg != null) errors['password'] = pwdMsg;
    }

    if (confirm.isEmpty) {
      errors['confirmPassword'] = 'Conferma la password.';
    } else if (password.isNotEmpty && password != confirm) {
      errors['confirmPassword'] = 'Le password non coincidono.';
    }

    if (!_privacyAccepted) {
      errors['privacy'] =
          'Devi leggere e accettare l\'informativa su privacy e consensi.';
    }

    if (errors.isNotEmpty) {
      setState(() {
        _clearRegisterFeedback();
        _registerFieldErrors.addAll(errors);
      });
      return false;
    }

    return true;
  }

  String _generateCpCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;

    setState(() {
      _busy = true;
      _clearLoginFeedback();
    });

    final fieldErrors = AuthFormValidation.validateLogin(
      email: email,
      password: password,
    );
    if (fieldErrors.isNotEmpty) {
      setState(() {
        _busy = false;
        _emailError = fieldErrors['email'];
        _passwordError = fieldErrors['password'];
      });
      return;
    }

    if (widget.unlockMode) {
      if (await _matchesSavedCredentials(email: email, password: password)) {
        await widget.onUnlocked?.call();
        setState(() => _busy = false);
        return;
      }
      if (!await ConnectivityService.isOnline()) {
        final current = FirebaseAuth.instance.currentUser;
        if (current != null &&
            (email.isEmpty || current.email == email)) {
          await widget.onUnlocked?.call();
          setState(() => _busy = false);
          return;
        }
        if (!mounted) return;
        setState(() {
          _busy = false;
          _loginNotice =
              'Senza connessione usa la biometria o la password già salvata '
              'su questo dispositivo.';
        });
        return;
      }
    } else if (!await ConnectivityService.isOnline()) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _loginNotice =
            'Senza connessione non è possibile accedere con email e password. '
            'Se hai già effettuato l\'accesso, chiudi l\'app e riaprila per '
            'sbloccarla con la biometria.';
      });
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (widget.unlockMode) {
        await widget.onUnlocked?.call();
        return;
      }
      try {
        await _saveCredentials(email, password);
        if (mounted) setState(() => _hasSavedCredentials = true);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loginNotice =
              'Accesso riuscito, ma la biometria non è stata attivata su questo dispositivo.';
        });
      }
    } on FirebaseAuthException catch (e) {
      final feedback = await AuthFormValidation.resolveLoginAuthFailure(e, email);
      if (!mounted) return;
      setState(() {
        _loginNotice = feedback.notice;
        _emailError = feedback.emailError;
        _passwordError = feedback.passwordError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loginNotice = 'Errore di connessione. Verifica la rete.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Recupero password'),
          content: const Text(
            'Inserisci l’email con cui ti sei registrato.\n'
            'Ti invieremo un link per reimpostare la password.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      // Silenzioso per sicurezza (non rivelare se l'email esiste).
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Email inviata'),
        content: Text(
          'Se l’indirizzo è registrato, abbiamo inviato un’email a:\n\n$email\n\n'
          'Controlla la posta (anche spam).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyConsents() async {
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegistrationPrivacyConsentsPage(),
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        _privacyAccepted = true;
        _registerFieldErrors.remove('privacy');
      });
    }
  }

  Future<String?> _showRegisterTypePopup() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Tipo di registrazione'),
        content: const Text('Seleziona il tipo di account'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: 120,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, 'public'),
              child: const Text('Utente'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, 'company'),
              child: const Text('Azienda'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (_registerType == null) return;

    final email = _email.text.trim();
    final password = _password.text.trim();
    final confirm = _confirmPassword.text.trim();

    setState(() {
      _busy = true;
      _clearRegisterFeedback();
    });

    if (!_validateRegisterForm(
      email: email,
      password: password,
      confirm: confirm,
    )) {
      setState(() => _busy = false);
      return;
    }

    final alreadyRegistered =
        await AuthFormValidation.emailRegisteredOnPlatform(email);
    if (alreadyRegistered) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _registerNotice =
            'Esiste già un account con questa email. Accedi o recupera la password.';
      });
      return;
    }

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) return;

      await user.sendEmailVerification();

      final cpCode = 'CP-${_generateCpCode()}';
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      final baseUserData = {
        'uid': user.uid,
        'email': email,
        'userCode': cpCode,
        'type': _registerType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_registerType == 'public') {
        await userRef.set({
          ...baseUserData,
          'name': _name.text.trim(),
          'surname': _surname.text.trim(),
          'onboardingDone': false,
        });

        await userRef.collection('seen_announcements').doc('_init').set({
          'createdAt': FieldValue.serverTimestamp(),
        });
        await userRef.collection('saved_jobs').doc('_init').set({
          'createdAt': FieldValue.serverTimestamp(),
        });
        await userRef.collection('consents_history').doc('_init').set({
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _saveRegistrationPrivacyConsent(userRef);
      }

      if (_registerType == 'company') {
        final companyName = _companyName.text.trim();
        final firestore = FirebaseFirestore.instance;
        final companyRef = firestore.collection('companies').doc(user.uid);

        await firestore.runTransaction((tx) async {
          tx.set(userRef, {
            ...baseUserData,
            'companyName': companyName,
            'companyCode': cpCode,
            'onboardingDone': false,
            'status': 'active',
          });

          tx.set(companyRef, {
            'companyId': user.uid,
            'companyCode': cpCode,
            'companyName': companyName,
            'piva': _piva.text.trim(),
            'phone': _phone.text.trim(),
            'referencePerson': _refPerson.text.trim(),
            'referenceRole': _refRole.text.trim(),
            'website': _website.text.trim(),
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });
        });

        try {
          final workCodesRef = firestore.collection('work_codes');
          await workCodesRef.doc('$cpCode-COL').set({
            'companyId': user.uid,
            'companyCode': cpCode,
            'companyName': companyName,
            'role': 'collaborator',
            'createdAt': FieldValue.serverTimestamp(),
          });
          await workCodesRef.doc('$cpCode-SUP').set({
            'companyId': user.uid,
            'companyCode': cpCode,
            'companyName': companyName,
            'role': 'supervisor',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}

        await companyRef.collection('rules_history').doc('_init').set({
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _saveRegistrationPrivacyConsent(userRef);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _registerNotice =
                'Esiste già un account con questa email. Accedi o recupera la password.';
          case 'invalid-email':
            _registerFieldErrors['email'] =
                'L’indirizzo email non sembra corretto.';
          case 'weak-password':
            _registerFieldErrors['password'] =
                'La password deve contenere almeno 8 caratteri e un carattere speciale.';
          default:
            _registerNotice =
                'Registrazione non riuscita. Controlla i dati e riprova.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _registerNotice = 'Errore durante la registrazione. Riprova più tardi.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildPrivacyConsentRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _openPrivacyConsents,
          icon: Icon(
            _privacyAccepted
                ? Icons.check_circle_outline
                : Icons.privacy_tip_outlined,
            color: _privacyAccepted ? Colors.green.shade700 : AppTheme.accent,
          ),
          label: Text(
            _privacyAccepted
                ? 'Privacy e consensi accettati'
                : 'Leggi privacy e consensi *',
            style: TextStyle(
              color: _privacyAccepted ? Colors.green.shade800 : AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            side: BorderSide(
              color: _privacyAccepted
                  ? Colors.green.shade400
                  : AppTheme.accent,
            ),
          ),
        ),
        if (!_privacyAccepted)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Obbligatorio: apri il documento, scorri fino in fondo e spunta il consenso.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _saveRegistrationPrivacyConsent(DocumentReference userRef) async {
    await userRef.collection('consents_history').doc('privacy_registration').set({
      'type': 'privacy_and_consents',
      'version': registrationPrivacyConsentsVersion,
      'acceptedAt': FieldValue.serverTimestamp(),
      'source': 'registration',
    });
  }

  Widget _buildNotice(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF5D4037), height: 1.4),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? errorText,
    bool obscure = false,
    TextInputType? keyboardType,
    VoidCallback? toggleObscure,
    Iterable<String>? autofillHints,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: errorText,
        suffixIcon: toggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: toggleObscure,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.body,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: const Border(
                      left: BorderSide(color: AppTheme.accent, width: 4),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111111),
                          ),
                          children: const [
                            TextSpan(
                              text: 'Credit',
                              style: TextStyle(color: Colors.black),
                            ),
                            TextSpan(
                              text: 'Core',
                              style: TextStyle(color: AppTheme.accent),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.unlockMode
                            ? 'Sblocca l\'app con biometria. Anche offline, se hai '
                                'già effettuato l\'accesso su questo dispositivo.'
                            : _isLogin
                                ? 'Accedi o registrati con le credenziali CreditCore.'
                                : 'Crea un account CreditCore.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 24),

                      if (_isLogin && _loginNotice != null) ...[
                        _buildNotice(_loginNotice!),
                        const SizedBox(height: 16),
                      ],
                      if (!_isLogin && _registerNotice != null) ...[
                        _buildNotice(_registerNotice!),
                        const SizedBox(height: 16),
                      ],
                      if (!_isLogin && _regError('privacy') != null) ...[
                        _buildNotice(_regError('privacy')!),
                        const SizedBox(height: 16),
                      ],

                      if (!_isLogin && _registerType == 'public') ...[
                        _field(
                          controller: _name,
                          label: 'Nome',
                          errorText: _regError('name'),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _surname,
                          label: 'Cognome',
                          errorText: _regError('surname'),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (!_isLogin && _registerType == 'company') ...[
                        _field(
                          controller: _companyName,
                          label: 'Ragione sociale',
                          errorText: _regError('companyName'),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _piva,
                          label: 'Partita IVA',
                          keyboardType: TextInputType.number,
                          errorText: _regError('piva'),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _phone,
                          label: 'Telefono',
                          keyboardType: TextInputType.phone,
                          errorText: _regError('phone'),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _refPerson,
                          label: 'Persona di riferimento',
                          errorText: _regError('refPerson'),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _refRole,
                          label: 'Ruolo',
                          errorText: _regError('refRole'),
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _website,
                          label: 'Sito internet',
                          errorText: _regError('website'),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _field(
                        controller: _email,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        errorText: _isLogin ? _emailError : _regError('email'),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _password,
                        label: 'Password',
                        obscure: _obscure,
                        autofillHints: const [AutofillHints.password],
                        errorText:
                            _isLogin ? _passwordError : _regError('password'),
                        toggleObscure: () => setState(() => _obscure = !_obscure),
                        onSubmitted: (_) {
                          if (!_busy) {
                            _isLogin ? _signIn() : _register();
                          }
                        },
                      ),

                      if (_isLogin) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : _resetPassword,
                            child: const Text(
                              'Password dimenticata?',
                              style: TextStyle(color: AppTheme.accent),
                            ),
                          ),
                        ),
                      ],

                      if (!_isLogin) ...[
                        const SizedBox(height: 12),
                        _field(
                          controller: _confirmPassword,
                          label: 'Conferma password',
                          obscure: true,
                          errorText: _regError('confirmPassword'),
                        ),
                        const SizedBox(height: 16),
                        _buildPrivacyConsentRow(),
                      ],

                      const SizedBox(height: 20),
                      if (_isLogin && _showBiometricButton)
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _busy ? null : _signIn,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Accedi'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _busy ? null : _signInBiometric,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Biometria'),
                              ),
                            ),
                          ],
                        )
                      else
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : (_isLogin ? _signIn : _register),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_isLogin ? 'Accedi' : 'Registrati'),
                        ),
                      if (_isLogin &&
                          _showBiometricButton &&
                          !_hasSavedCredentials &&
                          !widget.unlockMode) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Per attivare la biometria, accedi prima con email e password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (!widget.unlockMode) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                  if (_isLogin) {
                                    final type = await _showRegisterTypePopup();
                                    if (type == null || !mounted) return;
                                    setState(() {
                                      _registerType = type;
                                      _isLogin = false;
                                      _resetPrivacyAcceptance();
                                      _clearLoginFeedback();
                                      _clearRegisterFeedback();
                                    });
                                  } else {
                                    setState(() {
                                      _isLogin = true;
                                      _registerType = null;
                                      _resetPrivacyAcceptance();
                                      _clearRegisterFeedback();
                                    });
                                  }
                                },
                          child: Text(
                            _isLogin
                                ? 'Non hai un account? Registrati'
                                : 'Hai già un account? Accedi',
                            style: const TextStyle(color: AppTheme.accent),
                          ),
                        ),
                      ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
