/// Etichette corso per tab Sollecito (Corso 1, 2, …) e Recupero (Corso 1A, 2A, …).
abstract final class CourseLabels {
  static const String categorySollecito = 'Sollecito';
  static const String categoryRecupero = 'Recupero';

  static bool isRecuperoCategory(String category) =>
      category == categoryRecupero;

  /// [index] è 0-based (primo corso = 0 → Corso 1 o Corso 1A).
  static String label({required String category, required int index}) {
    final n = index + 1;
    if (isRecuperoCategory(category)) {
      return 'Corso ${n}A';
    }
    return 'Corso $n';
  }
}
