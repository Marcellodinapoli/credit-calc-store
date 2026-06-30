import 'package:cloud_firestore/cloud_firestore.dart';

import '../offline/utils/firestore_json_codec.dart';

/// Date/ora itinerario sempre nel fuso locale del dispositivo.
abstract final class ItineraryDateTime {
  static DateTime calendarDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime combineDateAndTime(DateTime date, int hour, int minute) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day, hour, minute);
  }

  static bool isSameCalendarDay(DateTime a, DateTime b) {
    final la = calendarDay(a);
    final lb = calendarDay(b);
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  static DateTime? parseStored(dynamic raw) {
    if (raw == null) return null;
    return _parseStoredValue(raw, depth: 0);
  }

  static DateTime? _parseStoredValue(dynamic raw, {required int depth}) {
    if (depth > 4) return null;
    final decoded = FirestoreJsonCodec.decodeValue(raw);
    if (decoded is Timestamp) return decoded.toDate().toLocal();
    if (decoded is DateTime) return decoded.toLocal();
    if (decoded is num) {
      return DateTime.fromMillisecondsSinceEpoch(decoded.toInt(), isUtc: true)
          .toLocal();
    }
    if (decoded is String) {
      final parsed = DateTime.tryParse(decoded);
      if (parsed != null) return parsed.toLocal();
    }
    if (decoded is Map) {
      return _parseStoredValue(decoded, depth: depth + 1);
    }
    return null;
  }

  static DateTime parseStoredOrNow(dynamic raw) =>
      parseStored(raw) ?? DateTime.now();
}
