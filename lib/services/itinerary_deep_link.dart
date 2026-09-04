import 'package:flutter/foundation.dart';

import '../shell/credit_calc_shell_nav.dart';
import 'package:credit_calc_core/credit_calc_core.dart';

enum ItineraryDeepLinkTarget {
  appointments,
  reminders,
}

class ItineraryDeepLinkRequest {
  const ItineraryDeepLinkRequest({
    required this.target,
    this.id,
  });

  final ItineraryDeepLinkTarget target;
  final String? id;
}

/// Richiesta di aprire una sotto-sezione Itinerario (da tap notifica).
abstract final class ItineraryDeepLink {
  static final ValueNotifier<ItineraryDeepLinkRequest?> request =
      ValueNotifier<ItineraryDeepLinkRequest?>(null);

  static void openAppointments({String? visitId}) {
    creditCalcActiveSection.value = CreditCalcNavItem.tools;
    request.value = ItineraryDeepLinkRequest(
      target: ItineraryDeepLinkTarget.appointments,
      id: visitId,
    );
  }

  static void openReminders({String? reminderId}) {
    creditCalcActiveSection.value = CreditCalcNavItem.tools;
    request.value = ItineraryDeepLinkRequest(
      target: ItineraryDeepLinkTarget.reminders,
      id: reminderId,
    );
  }

  static void clear() {
    request.value = null;
  }
}
