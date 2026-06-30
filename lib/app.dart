import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'core/app_localizations_config.dart';

class CreditCalcApp extends StatefulWidget {
  const CreditCalcApp({super.key});

  @override
  State<CreditCalcApp> createState() => _CreditCalcAppState();
}

class _CreditCalcAppState extends State<CreditCalcApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CreditCalc',
      debugShowCheckedModeBanner: false,
      locale: AppLocalizationsConfig.locale,
      localizationsDelegates: AppLocalizationsConfig.localizationsDelegates,
      supportedLocales: AppLocalizationsConfig.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ProjectColors.calc,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}
