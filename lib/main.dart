import 'package:firebase_core/firebase_core.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/credit_calc_host.dart';
import 'creditcalc/credit_calc_host_setup.dart';
import 'firebase_options.dart';
import 'offline/credit_calc_bootstrap_gate.dart';
import 'offline/sqflite_desktop_init.dart';
import 'services/fcm_service.dart';
import 'session/credit_core_session_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureSqfliteDesktopInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  registerCreditCalcHost();
  CreditCalcHostSetup.install();
  OnboardingHostConfig.buildHome = () => const CreditCoreSessionCoordinator(
        child: CreditCalcBootstrapGate(),
      );
  await FcmService.initialize();
  await RepaymentPlanSessionStorage.preload();
  runApp(const CreditCalcApp());
}
