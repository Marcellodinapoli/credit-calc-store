import 'package:flutter/foundation.dart';

/// Badge sulla voce «Itinerario» dopo un nuovo monitoraggio rate attivato.
final class ItineraryNavBadgeNotifier {
  ItineraryNavBadgeNotifier._();

  static final ItineraryNavBadgeNotifier instance =
      ItineraryNavBadgeNotifier._();

  final ValueNotifier<bool> pending = ValueNotifier(false);

  void markPending() => pending.value = true;

  void clear() => pending.value = false;
}
