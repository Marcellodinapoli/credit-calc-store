import 'package:cloud_firestore/cloud_firestore.dart';

import '../offline/repository/credit_calc_repository.dart';

/// Indirizzo sede visita salvato in anagrafica creditore.
abstract final class CreditorVisitAddressService {
  static Future<String?> lookupAddress({String? creditorId}) async {
    final id = creditorId?.trim();
    if (id == null || id.isEmpty) return null;

    final data = await _loadCreditorData(id);
    if (data == null) return null;

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

  static Future<Map<String, dynamic>?> _loadCreditorData(String id) async {
    try {
      final doc = await CreditCalcRepository.instance.getCreditor(id);
      return doc?.data;
    } catch (_) {
      final snap = await FirebaseFirestore.instance
          .collection('creditors')
          .doc(id)
          .get();
      if (!snap.exists) return null;
      return snap.data();
    }
  }
}
