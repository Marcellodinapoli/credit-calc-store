import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../session/credit_core_session_runtime.dart';
import '../offline/services/connectivity_service.dart';
import '../services/biometric_service.dart';
import '../services/creditcalc_gestionale_service.dart';
import 'biometric_lock_gate.dart';
import 'auth_form_validation.dart';
import 'auth_redirect_feedback.dart';
import '../widgets/public_page_shell.dart';
import '../widgets/public_top_menu.dart';
import 'login_pricing_page.dart';
import 'registration_coupon_field.dart';
import 'registration_coupon_service.dart';
import 'registration_company_code_field.dart';
import 'registration_plan_selection_page.dart';
import 'registration_plan_selection_result.dart';
import 'registration_privacy_consents_page.dart';
import 'registration_consents_service.dart';
import 'work_code_service.dart';
import 'work_company_link_service.dart';
import 'waiting_page.dart';

abstract final class AppTheme {
  static const accent = Color(0xFF0A66C2);
  static const accentDark = Color(0xFF084B8F);
  static const background = Color(0xFFF7F9FC);
  static const card = Colors.white;
  static const border = Color(0xFFE5E7EB);
  static const fieldFill = Color(0xFFF9FAFB);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const radius = 12.0;
  static const cardRadius = 16.0;
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
  String? _registerPlan;
  final _couponController = TextEditingController();
  RegistrationCouponValidation? _appliedCoupon;
  bool _couponChecking = false;
  String? _couponError;
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
  final _companyCode = TextEditingController();

  WorkCompanyLinkContext? _companyLinkContext;
  bool _validatingCompanyCode = false;
  String? _companyCodeError;

  bool get _companyLinkActive => _companyLinkContext != null;
  bool _obscure = true;
  bool _busy = false;

  String? _loginNotice;
  String? _emailError;
  String? _passwordError;
  String? _registerNotice;
  final Map<String, String> _registerFieldErrors = {};
  bool _privacyAccepted = false;
  String? _acceptedConsentVersion;

  @override
  void initState() {
    super.initState();
    final redirectMessage = AuthRedirectFeedback.consumeMessage();
    if (redirectMessage != null) {
      _loginNotice = redirectMessage;
    }
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
  }

  Future<void> _linkGestionaleSilently(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return;
    try {
      await CreditCalcGestionaleService.instance.tryAutoLinkFromAppLogin(
        email: email,
        password: password,
      );
    } catch (_) {}
  }

  Future<void> _saveCredentials(String email, String password) async {
    await _secureStorage.write(key: 'credit_calc_email', value: email);
    await _secureStorage.write(key: 'credit_calc_password', value: password);
    // Stesse credenziali → sessione pratiche in affido (se consulente abilitato).
    unawaited(_linkGestionaleSilently(email, password));
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

  Future<bool> _networkReadyForLogin() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return true;
    }
    return ConnectivityService.isOnline();
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
      BiometricLockGate.markUnlocked();
      final current = FirebaseAuth.instance.currentUser;
      if (current != null) {
        await widget.onUnlocked?.call();
        return;
      }
      await _restoreSessionWithSavedCredentials();
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
      await _linkGestionaleSilently(email, password);
      await _resumeAuthFlowAfterLogin();
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
      if (!mounted) return;
      try {
        await _saveCredentials(email, password);
        if (mounted) setState(() => _hasSavedCredentials = true);
      } catch (_) {}
      await _resumeAuthFlowAfterLogin();
    } on FirebaseAuthException catch (e) {
      if (_isNetworkAuthError(e)) {
        final restored = FirebaseAuth.instance.currentUser;
        if (restored != null && restored.email == email) {
          await _resumeAuthFlowAfterLogin();
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
        await _resumeAuthFlowAfterLogin();
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
        await _resumeAuthFlowAfterLogin();
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
    _companyCode.dispose();
    _couponController.dispose();
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

  void _clearCompanyLink() {
    _companyLinkContext = null;
    _companyCodeError = null;
    _validatingCompanyCode = false;
    _companyCode.clear();
  }

  Future<void> _validateCompanyCode() async {
    setState(() {
      _validatingCompanyCode = true;
      _companyCodeError = null;
    });

    final result = await WorkCodeService.validate(_companyCode.text);
    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _validatingCompanyCode = false;
        _companyCodeError = result.errorMessage;
        _companyLinkContext = null;
      });
      return;
    }

    final link = result.context!;
    final capacity = await WorkCompanyLinkService.checkCapacity(link.workCode);
    if (!mounted) return;

    if (!capacity.allowed) {
      setState(() {
        _validatingCompanyCode = false;
        _companyCodeError = capacity.message;
        _companyLinkContext = null;
      });
      return;
    }

    setState(() {
      _validatingCompanyCode = false;
      _companyLinkContext = link;
      _companyCode.text = link.workCode;
      _companyCodeError = null;
      _registerPlan = null;
      _registerFieldErrors.remove('plan');
      _clearRegistrationCoupon();
    });
  }

  void _resetPrivacyAcceptance() {
    _privacyAccepted = false;
    _acceptedConsentVersion = null;
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

    if (!_companyLinkActive &&
        (_registerPlan == null || _registerPlan!.trim().isEmpty)) {
      errors['plan'] = 'Seleziona un piano (Gratis, Plus o Enterprise).';
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

  bool get _couponActive => _appliedCoupon?.isValid == true;

  Future<void> _applyCoupon() async {
    final raw = _couponController.text;
    if (raw.trim().isEmpty) {
      setState(() {
        _couponError = 'Inserisci un codice coupon.';
        _appliedCoupon = null;
      });
      return;
    }

    setState(() {
      _couponChecking = true;
      _couponError = null;
    });

    final result = await RegistrationCouponService.validate(raw);
    if (!mounted) return;

    setState(() {
      _couponChecking = false;
      if (!result.isValid) {
        _appliedCoupon = null;
        _couponError = 'Coupon non valido, scaduto o esaurito.';
        return;
      }
      if (result.restrictedPlan != null &&
          _registerPlan != null &&
          result.restrictedPlan != _registerPlan) {
        _appliedCoupon = null;
        _couponError =
            'Questo coupon è valido solo per il piano '
            '${registrationPlanLabel(result.restrictedPlan)}.';
        return;
      }
      _appliedCoupon = result;
      _couponError = null;
    });
  }

  void _clearCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponError = null;
      _couponController.clear();
    });
  }

  void _clearRegistrationCoupon() {
    _appliedCoupon = null;
    _couponError = null;
    _couponChecking = false;
    _couponController.clear();
  }

  Future<RegistrationCouponValidation?> _resolveRegistrationCoupon() async {
    if (_appliedCoupon?.isValid == true) {
      return _appliedCoupon;
    }
    final raw = _couponController.text.trim();
    if (raw.isEmpty) return null;
    return RegistrationCouponService.validate(raw);
  }

  String _generateCpCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _restoreSessionWithSavedCredentials() async {
    final email = await _secureStorage.read(key: 'credit_calc_email');
    final password = await _secureStorage.read(key: 'credit_calc_password');
    if (email == null || password == null) {
      if (!mounted) return;
      setState(() {
        _loginNotice =
            'Sessione scaduta. Accedi con email e password per continuare.';
      });
      return;
    }

    setState(() => _busy = true);
    try {
      if (!await _networkReadyForLogin()) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _loginNotice =
              'Senza connessione non è possibile ripristinare la sessione. '
              'Riprova quando la rete è disponibile.';
        });
        return;
      }

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      await _linkGestionaleSilently(email, password);
      await widget.onUnlocked?.call();
    } on FirebaseAuthException catch (e) {
      final feedback = await AuthFormValidation.resolveLoginAuthFailure(e, email);
      if (!mounted) return;
      setState(() {
        _loginNotice = feedback.notice;
        _emailError = feedback.emailError;
        _passwordError = feedback.passwordError;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loginNotice =
            'Connessione lenta o non disponibile. Verifica la rete e riprova.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loginNotice =
            'Impossibile ripristinare la sessione. Accedi con email e password.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resumeAuthFlowAfterLogin() async {
    if (widget.unlockMode || !mounted) return;
    BiometricLockGate.markUnlocked();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    // AuthGate (route sotto) si aggiorna già via authStateChanges: basta chiudere login.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
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
        await _linkGestionaleSilently(
          email.isNotEmpty
              ? email
              : (FirebaseAuth.instance.currentUser?.email ?? ''),
          password,
        );
        await widget.onUnlocked?.call();
        setState(() => _busy = false);
        return;
      }
      if (!await _networkReadyForLogin()) {
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
    } else if (!await _networkReadyForLogin()) {
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
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 15));
      if (widget.unlockMode) {
        await _linkGestionaleSilently(email, password);
        await widget.onUnlocked?.call();
        return;
      }
      await _linkGestionaleSilently(email, password);
      await _resumeAuthFlowAfterLogin();
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
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loginNotice =
            'Connessione lenta o non disponibile. Verifica la rete e riprova.';
      });
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
    final version = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegistrationPrivacyConsentsPage(),
      ),
    );
    if (version != null && mounted) {
      setState(() {
        _privacyAccepted = true;
        _acceptedConsentVersion = version;
        _registerFieldErrors.remove('privacy');
      });
    }
  }

  Future<void> _applyPlanSelectionResult(
    RegistrationPlanSelectionResult result,
  ) async {
    setState(() {
      _registerPlan = result.planId;
      _registerFieldErrors.remove('plan');
    });

    if (result.couponApplied && result.couponCode != null) {
      _couponController.text = result.couponCode!;
      await _applyCoupon();
    } else {
      _clearRegistrationCoupon();
    }
  }

  Future<RegistrationPlanSelectionResult?> _openPlanSelection(
    String registerType,
  ) {
    return Navigator.of(context).push<RegistrationPlanSelectionResult>(
      MaterialPageRoute(
        builder: (_) => RegistrationPlanSelectionPage(registerType: registerType),
      ),
    );
  }

  Future<void> _startRegistration() async {
    final type = await _showRegisterTypePopup();
    if (type == null || !mounted) return;

    final result = await _openPlanSelection(type);
    if (result == null || !mounted) return;

    setState(() {
      _registerType = type;
      _registerPlan = result.planId;
      _clearCompanyLink();
      _clearRegistrationCoupon();
      _isLogin = false;
      _resetPrivacyAcceptance();
      _clearLoginFeedback();
      _clearRegisterFeedback();
    });
    await _applyPlanSelectionResult(result);
  }

  void _cancelRegistration() {
    setState(() {
      _isLogin = true;
      _registerType = null;
      _registerPlan = null;
      _clearCompanyLink();
      _clearRegistrationCoupon();
      _resetPrivacyAcceptance();
      _clearRegisterFeedback();
      _clearLoginFeedback();
    });
  }

  Future<void> _changeRegistrationPlan() async {
    if (_registerType == null) return;
    final result = await _openPlanSelection(_registerType!);
    if (result == null || !mounted) return;
    await _applyPlanSelectionResult(result);
  }

  Future<String?> _showRegisterTypePopup() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tipo di registrazione'),
        content: const Text('Seleziona il tipo di account'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, 'public'),
                  child: const Text('Utente'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, 'company'),
                  child: const Text('Azienda'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (_registerType == null) return;
    if (!_companyLinkActive && _registerPlan == null) return;

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
      if (_companyLinkActive && _registerType == 'public') {
        await _registerAsCompanyLinkedUser(email: email, password: password);
        return;
      }

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) return;

      RegistrationCouponValidation? coupon =
          await _resolveRegistrationCoupon();
      if (coupon != null && !coupon.isValid) {
        try {
          await user.delete();
        } catch (_) {}
        await CreditCoreSessionRuntime.signOutWithSessionRelease();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _appliedCoupon = null;
          _couponError = 'Coupon non valido, scaduto o esaurito.';
          _registerNotice =
              'Il coupon inserito non è valido, scaduto o esaurito.';
        });
        return;
      }
      if (coupon != null &&
          coupon.isValid &&
          coupon.restrictedPlan != null &&
          coupon.restrictedPlan != _registerPlan) {
        try {
          await user.delete();
        } catch (_) {}
        await CreditCoreSessionRuntime.signOutWithSessionRelease();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _couponError =
              'Il coupon è valido solo per il piano '
              '${registrationPlanLabel(coupon.restrictedPlan)}.';
          _registerNotice = _couponError;
        });
        return;
      }
      if (coupon?.isValid == true) {
        _appliedCoupon = coupon;
      }

      await user.sendEmailVerification();

      final cpCode = 'CP-${_generateCpCode()}';
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      final subscription = RegistrationCouponService.subscriptionFields(
        planId: _registerPlan!,
        coupon: coupon?.isValid == true ? coupon : null,
      );

      final baseUserData = {
        'uid': user.uid,
        'email': email,
        'userCode': cpCode,
        'type': _registerType,
        ...subscription,
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
        await _saveRegistrationPrivacyConsent(
          uid: user.uid,
          isCompany: false,
        );
        if (coupon?.isValid == true) {
          await RegistrationCouponService.markCouponUsed(
            code: coupon!.code,
            userId: user.uid,
          );
        }
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
            ...subscription,
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
        await _saveRegistrationPrivacyConsent(
          uid: user.uid,
          isCompany: true,
        );
        if (coupon?.isValid == true) {
          await RegistrationCouponService.markCouponUsed(
            code: coupon!.code,
            userId: user.uid,
          );
        }
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

  void _navigateToWaitingAfterRegistration(String email) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WaitingPage(
            email: email,
            status: 'pending',
          ),
        ),
      );
    });
  }

  Future<void> _registerAsCompanyLinkedUser({
    required String email,
    required String password,
  }) async {
    final link = _companyLinkContext;
    if (link == null) return;

    UserCredential? cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) return;

      await user.sendEmailVerification();

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await WorkCompanyLinkService.registerWorkUser(
        link: link,
        userRef: userRef,
        userData: {
          'uid': user.uid,
          'email': email,
          'name': _name.text.trim(),
          'surname': _surname.text.trim(),
          'type': 'work',
          'companyUid': link.companyId,
          'companyId': link.companyId,
          'companyCode': link.companyCode,
          'workRole': link.workRole,
          'workCode': link.workCode,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'onboardingDone': false,
        },
      );

      await _saveRegistrationPrivacyConsent(uid: user.uid, isCompany: false);

      if (!mounted) return;
      _navigateToWaitingAfterRegistration(email);
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
    } on StateError catch (e) {
      try {
        await cred?.user?.delete();
      } catch (_) {}
      try {
        await CreditCoreSessionRuntime.signOutWithSessionRelease();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _registerNotice = e.message.replaceFirst('Bad state: ', '');
      });
    } catch (_) {
      try {
        await cred?.user?.delete();
      } catch (_) {}
      try {
        await CreditCoreSessionRuntime.signOutWithSessionRelease();
      } catch (_) {}
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
            color: _privacyAccepted
                ? const Color(0xFF15803D)
                : AppTheme.accent,
          ),
          label: Text(
            _privacyAccepted
                ? 'Privacy e consensi accettati'
                : 'Leggi privacy e consensi *',
            style: TextStyle(
              color: _privacyAccepted
                  ? const Color(0xFF166534)
                  : AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            side: BorderSide(
              color: _privacyAccepted
                  ? const Color(0xFF86EFAC)
                  : AppTheme.border,
            ),
            backgroundColor: _privacyAccepted
                ? const Color(0xFFF0FDF4)
                : AppTheme.fieldFill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
          ),
        ),
        if (!_privacyAccepted)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Obbligatorio: apri il documento, scorri fino in fondo e spunta il consenso.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _saveRegistrationPrivacyConsent({
    required String uid,
    required bool isCompany,
  }) async {
    final version = _acceptedConsentVersion;
    if (version == null) return;

    await RegistrationConsentsService.saveAcceptance(
      uid: uid,
      version: version,
      source: isCompany ? 'company_registration' : 'registration',
      isCompany: isCompany,
    );
  }

  Widget _buildNotice(String text, {bool isError = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isError ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 18,
            color: isError ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isError
                    ? const Color(0xFF991B1B)
                    : const Color(0xFF92400E),
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? errorText,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      errorText: errorText,
      filled: true,
      fillColor: AppTheme.fieldFill,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppTheme.border),
      enabledBorder: border(AppTheme.border),
      focusedBorder: border(AppTheme.accent, width: 1.5),
      errorBorder: border(const Color(0xFFFCA5A5)),
      focusedErrorBorder: border(const Color(0xFFEF4444), width: 1.5),
      labelStyle: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 14,
      ),
    );
  }

  ButtonStyle get _primaryButtonStyle => FilledButton.styleFrom(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.45),
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      );

  Widget _buildBrandHeader() {
    final subtitle = widget.unlockMode
        ? 'Scegli come sbloccare l\'app: password o biometria.'
        : _isLogin
            ? 'Accedi al tuo workspace CreditCore.'
            : 'Crea il tuo account in pochi passaggi.';

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: 52,
            height: 52,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
              height: 1.1,
            ),
            children: const [
              TextSpan(text: 'Credit'),
              TextSpan(text: 'Core', style: TextStyle(color: AppTheme.accent)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.fieldFill,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeTab(
              label: 'Accedi',
              selected: _isLogin,
              onTap: _busy
                  ? null
                  : () {
                      if (_isLogin) return;
                      setState(() {
                        _isLogin = true;
                        _registerType = null;
                        _registerPlan = null;
                        _clearCompanyLink();
                        _clearRegistrationCoupon();
                        _resetPrivacyAcceptance();
                        _clearRegisterFeedback();
                      });
                    },
            ),
          ),
          Expanded(
            child: _AuthModeTab(
              label: 'Registrati',
              selected: !_isLogin,
              onTap: _busy
                  ? null
                  : () async {
                      if (!_isLogin) return;
                      await _startRegistration();
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildRegisterTypeBadge() {
    if (_isLogin || _registerType == null) return null;
    final isCompany = _registerType == 'company';
    final planLabel = _registerPlan == null
        ? null
        : registrationPlanLabel(_registerPlan);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : _changeRegistrationPlan,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCompany ? Icons.business_center_outlined : Icons.person_outline,
                size: 16,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 6),
              Text(
                planLabel == null
                    ? (isCompany ? 'Registrazione azienda' : 'Registrazione utente')
                    : '${isCompany ? 'Azienda' : 'Utente'} · Piano $planLabel',
                style: const TextStyle(
                  color: AppTheme.accentDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.edit_outlined,
                size: 14,
                color: AppTheme.accent,
              ),
            ],
          ),
        ),
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
      style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
      decoration: _inputDecoration(
        label: label,
        errorText: errorText,
        suffixIcon: toggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                onPressed: toggleObscure,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isRegistration = !_isLogin;
    final maxCardWidth = min(
      isRegistration ? 460.0 : 380.0,
      screenWidth - (isRegistration ? 24 : 32),
    );

    final loginCard = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxCardWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.07),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth < 400 ? 18 : 24,
            vertical: screenWidth < 400 ? 20 : 28,
          ),
          child: _buildLoginForm(),
        ),
      ),
    );

    if (widget.unlockMode) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: _buildResponsiveLoginBody(loginCard),
        ),
      );
    }

    return PublicPageShell(
      current: PublicPage.login,
      scrollable: false,
      includeBottomSafeArea: isRegistration,
      child: _buildResponsiveLoginBody(loginCard),
    );
  }

  Widget _buildResponsiveLoginBody(Widget loginCard) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final compact = PublicPageShell.isMobile(context);
        final isRegistration = !_isLogin;
        final horizontal = compact ? 16.0 : 24.0;
        final topPadding = compact ? 8.0 : 20.0;
        final bottomPadding = media.padding.bottom +
            media.viewInsets.bottom +
            (isRegistration ? 32.0 : 16.0);

        if (isRegistration) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontal,
              topPadding,
              horizontal,
              bottomPadding,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: loginCard,
            ),
          );
        }

        final centeredCard = Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topPadding,
            horizontal,
            bottomPadding,
          ),
          child: Align(
            alignment: Alignment.center,
            child: loginCard,
          ),
        );

        if (!compact) {
          return centeredCard;
        }

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: centeredCard,
          ),
        );
      },
    );
  }

  Widget _buildLoginForm() {
    final registerBadge = _buildRegisterTypeBadge();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBrandHeader(),
        if (!widget.unlockMode) ...[
          const SizedBox(height: 22),
          _buildAuthModeSelector(),
        ],
        if (registerBadge != null) ...[
          const SizedBox(height: 16),
          Center(child: registerBadge),
        ],
        const SizedBox(height: 22),
        const Divider(height: 1, color: AppTheme.border),
        const SizedBox(height: 22),

        if (_isLogin && _loginNotice != null) ...[
          _buildNotice(_loginNotice!),
          const SizedBox(height: 16),
        ],
        if (!_isLogin && _registerNotice != null) ...[
          _buildNotice(_registerNotice!),
          const SizedBox(height: 16),
        ],
        if (!_isLogin && _regError('privacy') != null) ...[
          _buildNotice(_regError('privacy')!, isError: true),
          const SizedBox(height: 16),
        ],

        if (!_isLogin && _registerType == 'public') ...[
          _field(
            controller: _name,
            label: 'Nome',
            errorText: _regError('name'),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _surname,
            label: 'Cognome',
            errorText: _regError('surname'),
          ),
          const SizedBox(height: 14),
        ],

        if (!_isLogin && _registerType == 'company') ...[
          _field(
            controller: _companyName,
            label: 'Ragione sociale',
            errorText: _regError('companyName'),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _piva,
            label: 'Partita IVA',
            keyboardType: TextInputType.number,
            errorText: _regError('piva'),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _phone,
            label: 'Telefono',
            keyboardType: TextInputType.phone,
            errorText: _regError('phone'),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _refPerson,
            label: 'Persona di riferimento',
            errorText: _regError('refPerson'),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _refRole,
            label: 'Ruolo',
            errorText: _regError('refRole'),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _website,
            label: 'Sito internet',
            errorText: _regError('website'),
          ),
          const SizedBox(height: 14),
        ],

        if (!_isLogin &&
            _registerType == 'public') ...[
          RegistrationCompanyCodeField(
            controller: _companyCode,
            validating: _validatingCompanyCode,
            linked: _companyLinkActive,
            linkedCompanyName: _companyLinkContext?.companyName,
            errorText: _companyCodeError,
            onValidate: _validateCompanyCode,
            onClear: () {
              setState(() {
                _clearCompanyLink();
                _registerPlan ??= 'free';
              });
            },
          ),
          const SizedBox(height: 14),
        ],

        _field(
          controller: _email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          errorText: _isLogin ? _emailError : _regError('email'),
        ),
        const SizedBox(height: 14),
        _field(
          controller: _password,
          label: 'Password',
          obscure: _obscure,
          autofillHints: const [AutofillHints.password],
          errorText: _isLogin ? _passwordError : _regError('password'),
          toggleObscure: () => setState(() => _obscure = !_obscure),
          onSubmitted: (_) {
            if (!_busy) {
              _isLogin ? _signIn() : _register();
            }
          },
        ),

        if (_isLogin && !widget.unlockMode) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _resetPassword,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accent,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Password dimenticata?'),
            ),
          ),
        ],

        if (!_isLogin) ...[
          const SizedBox(height: 4),
          _field(
            controller: _confirmPassword,
            label: 'Conferma password',
            obscure: true,
            errorText: _regError('confirmPassword'),
          ),
          const SizedBox(height: 16),
          if (!_companyLinkActive)
            RegistrationCouponSection(
              controller: _couponController,
              checking: _couponChecking,
              error: _couponError,
              applied: _couponActive,
              appliedCoupon: _appliedCoupon,
              onApply: _applyCoupon,
              onClear: _clearCoupon,
            ),
          if (!_companyLinkActive) const SizedBox(height: 16),
          _buildPrivacyConsentRow(),
        ],

        const SizedBox(height: 20),
        if (_isLogin && (_showBiometricButton || widget.unlockMode))
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _signIn,
                  style: _primaryButtonStyle,
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
                child: OutlinedButton(
                  onPressed: _busy ? null : _signInBiometric,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: AppTheme.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Biometria'),
                ),
              ),
            ],
          )
        else
          FilledButton(
            onPressed: _busy ? null : (_isLogin ? _signIn : _register),
            style: _primaryButtonStyle,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isLogin ? 'Accedi' : 'Crea account'),
          ),
        if (!_isLogin) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _cancelRegistration,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: AppTheme.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Annulla'),
          ),
        ],
        if (_isLogin &&
            _showBiometricButton &&
            !_hasSavedCredentials &&
            !widget.unlockMode) ...[
          const SizedBox(height: 12),
          Text(
            'Per attivare la biometria, accedi prima con email e password.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
        if (!widget.unlockMode && _isLogin) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoginPricingPage(),
                        ),
                      );
                    },
              style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
              child: const Text('Consulta piani e prezzi'),
            ),
          ),
        ],
        if (!widget.unlockMode) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              _isLogin
                  ? 'Non hai un account? Usa la scheda Registrati in alto.'
                  : 'Hai già un account? Usa la scheda Accedi in alto.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
        if (!_isLogin) const SizedBox(height: 8),
      ],
    );
  }
}

class _AuthModeTab extends StatelessWidget {
  const _AuthModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppTheme.accent : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
