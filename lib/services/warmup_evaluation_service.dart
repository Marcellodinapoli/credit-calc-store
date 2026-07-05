import 'dart:convert';

import 'callable_function_client.dart';

abstract final class WarmupEvaluationService {
  static Future<Map<String, dynamic>> evaluate({
    required List<int> audioBytes,
    required String phase,
    required String expectedText,
    required String phaseExplanation,
    required String customerLine,
    String mimeType = 'audio/m4a',
    String kind = 'warmup',
  }) async {
    final data = await CallableFunctionClient.call('warmupEvaluate', {
      'audioBase64': base64Encode(audioBytes),
      'mimeType': mimeType,
      'phase': phase,
      'expectedText': expectedText,
      'phaseExplanation': phaseExplanation,
      'customerLine': customerLine,
      'kind': kind,
    });

    if (data is! Map) {
      throw Exception('Risposta non valida dal server.');
    }
    return Map<String, dynamic>.from(data);
  }
}
