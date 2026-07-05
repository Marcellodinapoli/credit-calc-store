import '../models/call_analysis/call_analysis_form_data.dart';
import 'callable_function_client.dart';

abstract final class CallAnalysisService {
  static Future<String> analyze({
    required CallAnalysisPracticeData practice,
    required String systemPrompt,
  }) async {
    final data = await CallableFunctionClient.call('callAnalysis', {
      'prompt': systemPrompt,
      'practiceData': practice.toJson(),
      'practiceText': practice.toAnalysisText(),
    });

    if (data is! Map) {
      throw Exception('Risposta non valida dal server.');
    }
    return (data['analysis'] ?? '').toString().trim();
  }
}
