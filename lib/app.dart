import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'auth/auth_gate.dart';
import 'core/app_localizations_config.dart';
import 'widgets/desktop_app_update_button.dart';

class CreditCalcApp extends StatefulWidget {
  const CreditCalcApp({super.key});

  @override
  State<CreditCalcApp> createState() => _CreditCalcAppState();
}

class _CreditCalcAppState extends State<CreditCalcApp> {
  String? _windowTitle;

  @override
  void initState() {
    super.initState();
    DesktopAppUpdateButton.packageInfoFuture.then((info) {
      if (!mounted) return;
      setState(() => _windowTitle = 'CreditCalc v${info.version}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _windowTitle ?? 'CreditCalc',
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
