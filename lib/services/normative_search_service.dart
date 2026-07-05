import 'callable_function_client.dart';

abstract final class NormativeSearchService {
  static Future<String> ask({
    required String question,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
  }) async {
    final data = await CallableFunctionClient.call('normativeSearch', {
      'question': question,
      'prompt': systemPrompt,
      'history': history,
    });

    if (data is! Map) {
      throw Exception('Risposta non valida dal server.');
    }
    return (data['answer'] ?? '').toString().trim();
  }
}
