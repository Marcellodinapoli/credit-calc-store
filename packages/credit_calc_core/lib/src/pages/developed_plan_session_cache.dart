/// Mantiene in memoria l'ultimo piano sviluppato per tipo pagina,
/// così Esc / cambio schermata / ritorno non richiedono un nuovo «Sviluppa».
abstract final class DevelopedPlanSessionCache {
  DevelopedPlanSessionCache._();

  static const standardRepayment = 'standard_repayment';
  static const balanceWriteOff = 'balance_write_off';

  static final Map<String, Map<String, dynamic>> _entries = {};

  static Map<String, dynamic>? read(String planType) => _entries[planType];

  static void save(String planType, Map<String, dynamic> state) {
    _entries[planType] = Map<String, dynamic>.from(state);
  }

  static void clear(String planType) => _entries.remove(planType);

  static void clearAll() => _entries.clear();
}
