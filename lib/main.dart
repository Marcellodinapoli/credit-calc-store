import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/credit_calc_host.dart';
import 'firebase_options.dart';
import 'pages/creditcalc/repayment_plan_session_storage.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  registerCreditCalcHost();
  await FcmService.initialize();
  await RepaymentPlanSessionStorage.preload();
  runApp(const CreditCalcApp());
}
