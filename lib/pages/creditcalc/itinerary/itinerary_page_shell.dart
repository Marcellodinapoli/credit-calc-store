import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../area/personal_area_shell.dart';

class ItineraryPageShell {
  const ItineraryPageShell({this.personalArea = false});

  final bool personalArea;

  Widget primary({required String pageTitle, required Widget body}) {
    if (personalArea) {
      return PersonalAreaShell(pageTitle: pageTitle, body: body);
    }
    return wrapCreditCalcPage(
      pageTitle: pageTitle,
      current: CreditCalcNavItem.develop,
      body: body,
    );
  }

  Widget secondary({required String pageTitle, required Widget body}) {
    if (personalArea) {
      return PersonalAreaShell(pageTitle: pageTitle, body: body);
    }
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: pageTitle,
      current: CreditCalcNavItem.develop,
      body: body,
    );
  }
}
