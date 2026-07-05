import 'callable_function_client.dart';

abstract final class RoleplayConversationService {
  static Future<Map<String, dynamic>> step({
    required String userText,
    required String prompt,
    required String sessionId,
    required List<Map<String, String>> history,
    List<dynamic> practiceData = const [],
    Map<String, dynamic>? scenarioWeights,
    String? responderRole,
    String? familyRelation,
    String? difficulty,
    String? personality,
  }) async {
    final data = await CallableFunctionClient.call('roleplayStep', {
      'userText': userText,
      'prompt': prompt,
      'sessionId': sessionId,
      'history': history,
      'practiceData': practiceData,
      if (scenarioWeights != null) 'scenarioWeights': scenarioWeights,
      if (responderRole != null) 'responderRole': responderRole,
      if (familyRelation != null) 'familyRelation': familyRelation,
      if (difficulty != null) 'difficulty': difficulty,
      if (personality != null) 'personality': personality,
    });

    if (data is! Map) {
      throw Exception('Risposta non valida dal server.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<String> suggestion({
    required String prompt,
    required String title,
    required List<Map<String, String>> history,
    String practiceText = '',
  }) async {
    final data = await CallableFunctionClient.call('roleplaySuggestion', {
      'prompt': prompt,
      'title': title,
      'history': history,
      'practiceText': practiceText,
    });

    if (data is! Map) {
      throw Exception('Risposta non valida dal server.');
    }
    return (data['suggestion'] ?? '').toString().trim();
  }
}
