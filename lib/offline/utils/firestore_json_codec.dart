import 'package:cloud_firestore/cloud_firestore.dart';

/// Converte tipi Firestore in valori JSON-serializzabili per SQLite.
abstract final class FirestoreJsonCodec {
  static const _timestampKey = '__firestore_timestamp__';
  static const _geoPointKey = '__firestore_geopoint__';

  static Map<String, dynamic> encodeMap(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, encodeValue(value)));
  }

  static dynamic encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {_timestampKey: value.millisecondsSinceEpoch};
    }
    if (value is DateTime) {
      return {_timestampKey: value.millisecondsSinceEpoch};
    }
    if (value is GeoPoint) {
      return {_geoPointKey: [value.latitude, value.longitude]};
    }
    if (value is Map) {
      return encodeMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(encodeValue).toList();
    }
    return value;
  }

  static Map<String, dynamic> decodeMap(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, decodeValue(value)));
  }

  static dynamic decodeValue(dynamic value) {
    if (value is Map) {
      if (value.length == 1 && value.containsKey(_timestampKey)) {
        return Timestamp.fromMillisecondsSinceEpoch(
          value[_timestampKey] as int,
        );
      }
      if (value.length == 1 && value.containsKey(_geoPointKey)) {
        final coords = value[_geoPointKey] as List;
        return GeoPoint(coords[0] as double, coords[1] as double);
      }
      return decodeMap(Map<String, dynamic>.from(value));
    }
    if (value is List) {
      return value.map(decodeValue).toList();
    }
    return value;
  }
}
