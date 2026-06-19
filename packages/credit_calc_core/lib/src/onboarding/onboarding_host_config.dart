import 'package:flutter/material.dart';

/// Host Planet o CreditCalc Store: destinazione dopo il carousel.
abstract final class OnboardingHostConfig {
  OnboardingHostConfig._();

  static Widget Function()? buildHome;

  static void navigateToHome(BuildContext context) {
    final builder = buildHome;
    if (builder == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => builder()),
    );
  }
}
