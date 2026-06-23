import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/normative_search_backend_config.dart';

abstract final class NormativeSearchService {
  static Future<String> ask({
    required String question,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
  }) async {
    final response = await http
        .post(
          Uri.parse(NormativeSearchBackendConfig.httpUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'question': question,
            'prompt': systemPrompt,
            'history': history,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    return (data['answer'] ?? '').toString().trim();
  }
}
