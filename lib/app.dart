import 'package:credit_calc_core/credit_calc_core.dart' hide AppCardTheme;
import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'core/app_localizations_config.dart';
import 'core/theme/app_card_theme.dart';
import 'core/theme/app_surface_theme.dart';

class CreditCalcApp extends StatelessWidget {
  const CreditCalcApp({super.key});

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
          surface: AppSurfaceTheme.page,
        ),
        scaffoldBackgroundColor: AppSurfaceTheme.page,
        cardTheme: AppCardTheme.cardTheme,
        dialogTheme: AppSurfaceTheme.dialogTheme(),
        bottomSheetTheme: AppSurfaceTheme.bottomSheetTheme,
        popupMenuTheme: AppSurfaceTheme.popupMenuTheme,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}
