import 'package:cloud_firestore/cloud_firestore.dart';

class AiUsageMonthStats {
  final int calls;
  final int inputTokens;
  final int outputTokens;
  final int inputAudioTokens;
  final int outputAudioTokens;
  final int cachedTokens;
  final double estimatedEur;

  const AiUsageMonthStats({
    required this.calls,
    required this.inputTokens,
    required this.outputTokens,
    required this.inputAudioTokens,
    required this.outputAudioTokens,
    required this.cachedTokens,
    required this.estimatedEur,
  });

  int get totalTokens => inputTokens + outputTokens;

  static const empty = AiUsageMonthStats(
    calls: 0,
    inputTokens: 0,
    outputTokens: 0,
    inputAudioTokens: 0,
    outputAudioTokens: 0,
    cachedTokens: 0,
    estimatedEur: 0,
  );

  factory AiUsageMonthStats.fromFirestore(Map<String, dynamic>? data) {
    final totals = data?['totals'];
    final map = totals is Map<String, dynamic>
        ? totals
        : totals is Map
            ? Map<String, dynamic>.from(totals)
            : const <String, dynamic>{};
    return AiUsageMonthStats(
      calls: _asInt(map['calls']),
      inputTokens: _asInt(map['inputTokens']),
      outputTokens: _asInt(map['outputTokens']),
      inputAudioTokens: _asInt(map['inputAudioTokens']),
      outputAudioTokens: _asInt(map['outputAudioTokens']),
      cachedTokens: _asInt(map['cachedTokens']),
      estimatedEur: _asDouble(map['estimatedEur']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

abstract final class AiUsageAdminService {
  static String currentMonthKey([DateTime? now]) {
    final value = now ?? DateTime.now().toUtc();
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }

  static Stream<AiUsageMonthStats> watchCurrentMonthTotals() {
    return FirebaseFirestore.instance
        .collection('settings')
        .doc('ai_usage')
        .collection('months')
        .doc(currentMonthKey())
        .snapshots()
        .map((snapshot) => AiUsageMonthStats.fromFirestore(snapshot.data()));
  }
}
