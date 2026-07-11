import '../models/warmup_contestation.dart';
import 'callable_function_client.dart';

class ContestationGenerateResult {
  const ContestationGenerateResult({
    required this.meaning,
    required this.risk,
    required this.objective,
    required this.response,
    required this.category,
  });

  final String meaning;
  final String risk;
  final String objective;
  final String response;
  final WarmupContestationCategory category;
}

abstract final class ContestationGenerateService {
  static Future<ContestationGenerateResult> generate({
    required String declared,
    required WarmupContestationContext context,
  }) async {
    final data = await CallableFunctionClient.call('contestationGenerate', {
      'declared': declared.trim(),
      'context': context.firestoreValue,
    });

    if (data is! Map) {
      throw Exception('Risposta non valida dal server.');
    }

    final map = Map<String, dynamic>.from(data);
    final meaning = (map['meaning'] ?? '').toString().trim();
    final risk = (map['risk'] ?? '').toString().trim();
    final objective = (map['objective'] ?? '').toString().trim();
    final response = (map['response'] ?? '').toString().trim();

    if (meaning.isEmpty ||
        risk.isEmpty ||
        objective.isEmpty ||
        response.isEmpty) {
      throw Exception('L\'AI non ha compilato tutte le schede di analisi.');
    }

    return ContestationGenerateResult(
      meaning: meaning,
      risk: risk,
      objective: objective,
      response: response,
      category: WarmupContestationCategory.fromString(
        map['category']?.toString(),
      ),
    );
  }
}
