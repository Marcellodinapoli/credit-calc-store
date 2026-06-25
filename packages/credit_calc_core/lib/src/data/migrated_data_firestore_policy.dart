/// Politica accesso Firestore per dati operativi con ragione sociale / nominativi.
///
/// L'host (web CreditCore, app store con sync locale) imposta [isLocalPrimary]
/// al login e lo azzera al logout. Le implementazioni Firestore dei data-access
/// devono chiamare [assertFirestoreAccessAllowed] prima di ogni lettura o scrittura.
abstract final class MigratedDataFirestorePolicy {
  MigratedDataFirestorePolicy._();

  /// Es. `() => DevelopLocalStore.isActive` su CreditCore web.
  static bool Function()? isLocalPrimary;

  static bool get firestoreAccessDisabled => isLocalPrimary?.call() ?? false;

  @Deprecated('Usa firestoreAccessDisabled')
  static bool get writesDisabled => firestoreAccessDisabled;

  static void assertFirestoreAccessAllowed() {
    if (firestoreAccessDisabled) {
      throw StateError(
        'Accesso Firestore disabilitato: i dati con ragione sociale sono '
        'gestiti in locale su questo dispositivo.',
      );
    }
  }

  static void assertWritesAllowed() => assertFirestoreAccessAllowed();
}
