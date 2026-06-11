import '../offline/repository/credit_calc_repository.dart';

/// Indirizzo sede visita salvato in anagrafica creditore.
abstract final class CreditorVisitAddressService {
  static Future<String?> lookupAddress({String? creditorId}) async {
    final id = creditorId?.trim();
    if (id == null || id.isEmpty) return null;

    final doc = await CreditCalcRepository.instance.getCreditor(id);
    if (doc == null) return null;

    final data = doc.data;
    final visitAddress = (data['visitAddress'] ?? '').toString().trim();
    if (visitAddress.isNotEmpty) return visitAddress;

    final payments = data['paymentCoordinates'];
    if (payments is Map) {
      for (final key in ['indVo', 'indBp']) {
        final fallback = (payments[key] ?? '').toString().trim();
        if (fallback.isNotEmpty) return fallback;
      }
    }
    return null;
  }
}
