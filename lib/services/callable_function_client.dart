import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Invoca Firebase Callable Functions su tutte le piattaforme.
///
/// Su Windows/Linux il plugin [cloud_functions] non è disponibile: si usa
/// l'endpoint HTTP documentato da Firebase con token Auth.
abstract final class CallableFunctionClient {
  static const _region = 'europe-west1';
  static const _projectId = 'creditform-d505d';

  static bool get _useHttp =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  static Future<dynamic> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (_useHttp) {
      return _callViaHttp(name, data);
    }

    final result = await FirebaseFunctions.instanceFor(region: _region)
        .httpsCallable(name)
        .call(data);
    return result.data;
  }

  static const _httpTimeout = Duration(seconds: 30);

  static Future<dynamic> _callViaHttp(
    String name,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Utente non autenticato.');
    }

    final token = await user.getIdToken().timeout(_httpTimeout);
    final url = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/$name',
    );

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'data': data}),
        )
        .timeout(_httpTimeout);

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      payload = decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      throw Exception(
        'Risposta non valida dal server (${response.statusCode}).',
      );
    }

    final error = payload['error'];
    if (error != null) {
      final message = error is Map
          ? (error['message'] ?? error['status']).toString()
          : error.toString();
      throw Exception(message.isNotEmpty ? message : 'Errore function.');
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return payload['result'];
  }
}
