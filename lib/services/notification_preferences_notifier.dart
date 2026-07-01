import 'dart:async';

/// Sincronizza in tempo reale le preferenze notifiche tra pagine (Notifiche ↔ Itinerario).
final class NotificationPreferencesNotifier {
  NotificationPreferencesNotifier._();

  static final NotificationPreferencesNotifier instance =
      NotificationPreferencesNotifier._();

  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  void notifyChanged() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }
}
