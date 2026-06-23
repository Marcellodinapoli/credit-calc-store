import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/call_analysis_backend_config.dart';
import '../models/call_analysis_practice_data.dart';

abstract final class CallAnalysisService {
  static Future<String> analyze({
    required CallAnalysisPracticeData practice,
    required String systemPrompt,
  }) async {
    final response = await http
        .post(
          Uri.parse(CallAnalysisBackendConfig.httpUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'prompt': systemPrompt,
            'practiceData': practice.toJson(),
            'practiceText': practice.toAnalysisText(),
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : Map<String, dynamic>.from(decoded as Map);
    return (data['analysis'] ?? '').toString().trim();
  }
}
