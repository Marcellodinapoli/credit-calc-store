import 'package:flutter/material.dart';

import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';
import 'subscription_account_body.dart';

/// Pagina piano/abbonamento per CreditCalc Store (app e desktop).
class SubscriptionAccountPage extends StatelessWidget {
  const SubscriptionAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      pageTitle: 'Il mio piano',
      current: CreditCalcNavItem.subscription,
      body: const SubscriptionAccountBody(),
    );
  }
}
