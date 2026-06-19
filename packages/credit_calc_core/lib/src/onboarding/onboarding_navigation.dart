import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/user_account_status.dart';
import 'onboarding_carousel_page.dart';
import 'onboarding_host_config.dart';

/// Dopo verifica email / login attivo: carousel filtrato per tipo utente, poi home.
abstract final class OnboardingNavigation {
  OnboardingNavigation._();

  static bool needsOnboarding({
    required String? userType,
    required bool onboardingDone,
  }) {
    if (onboardingDone) return false;
    final type = userType?.trim().toLowerCase();
    return type == 'public' || type == 'work' || type == 'company';
  }

  static Future<bool> needsOnboardingForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final companyDoc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(user.uid)
        .get();

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data() ?? {};
    final userType = (userData['type'] ?? 'public').toString();
    final onboardingDone = userData['onboardingDone'] == true;

    if (companyDoc.exists &&
        needsOnboarding(userType: 'company', onboardingDone: onboardingDone)) {
      return true;
    }

    return needsOnboarding(userType: userType, onboardingDone: onboardingDone);
  }

  /// Public: form + calc + job | Work: form + calc | Company: job (+ slide finale).
  static Future<void> goToHomeOrOnboarding(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !context.mounted) return;

    await UserAccountStatus.recordLastLoginAt(user.uid);

    final show = await needsOnboardingForCurrentUser();
    if (!context.mounted) return;

    if (show) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingCarouselPage()),
      );
      return;
    }

    OnboardingHostConfig.navigateToHome(context);
  }
}
