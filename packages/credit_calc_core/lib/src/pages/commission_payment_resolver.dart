/// Deriva le modalità di pagamento previste dalla scheda creditore.
abstract final class CommissionPaymentResolver {
  static const paymentMethodLabels = <String, String>{
    'contanti': 'Contanti',
    'bollettinoPostale': 'Bollettino postale',
    'assegnoBancario': 'Assegno bancario',
    'bonificoBancarioPostale': 'Bonifico bancario/postale',
    'vagliaOrdinaria': 'Vaglia ordinaria (Vo)',
    'pdrEffettiCambiari': 'Pdr c/effetti cambiari',
    'pdrBollettiniPostali': 'Pdr c/bollettini postali',
  };

  static String labelForKey(String key) =>
      paymentMethodLabels[key] ?? key;

  static bool _hasCoord(Map<String, dynamic> payments, String key) {
    final value = payments[key];
    return value != null && value.toString().trim().isNotEmpty;
  }

  static Map<String, bool> allowedMethods(Map<String, dynamic> creditorData) {
    final payments =
        (creditorData['paymentCoordinates'] as Map<String, dynamic>?) ?? {};
    final methods =
        (creditorData['paymentMethods'] as Map<String, dynamic>?) ?? {};

    return {
      'contanti': methods['contanti'] == true,
      'bollettinoPostale': _hasCoord(payments, 'bpHeader') ||
          _hasCoord(payments, 'ccp') ||
          _hasCoord(payments, 'indBp'),
      'assegnoBancario': _hasCoord(payments, 'assHeader'),
      'bonificoBancarioPostale': _hasCoord(payments, 'bbHeader') ||
          _hasCoord(payments, 'iban'),
      'vagliaOrdinaria': _hasCoord(payments, 'voHeader') ||
          _hasCoord(payments, 'indVo'),
      'pdrEffettiCambiari': methods['effettiCambiari'] == true,
      'pdrBollettiniPostali': methods['bollettiniPostali'] == true,
    };
  }

  static int countAllowed(Map<String, bool> allowed) =>
      allowed.values.where((v) => v).length;

  /// Modalità con aliquota configurata, per l'inserimento provvigioni.
  static List<CommissionPaymentOption> entryOptions(
    Map<String, dynamic> creditorData,
  ) {
    final allowed = allowedMethods(creditorData);
    final settings =
        (creditorData['commissionSettings'] as Map<String, dynamic>?) ?? {};
    final options = <CommissionPaymentOption>[];

    for (final entry in paymentMethodLabels.entries) {
      if (allowed[entry.key] != true) continue;

      final setting = settings[entry.key];
      if (setting is! Map<String, dynamic>) continue;

      final rateRaw = (setting['rate'] ?? '').toString().trim();
      if (rateRaw.isEmpty) continue;

      final rate = double.tryParse(rateRaw.replaceAll(',', '.'));
      if (rate == null) continue;

      options.add(
        CommissionPaymentOption(
          key: entry.key,
          label: entry.value,
          rate: rate,
        ),
      );
    }

    return options;
  }
}

class CommissionPaymentOption {
  final String key;
  final String label;
  final double rate;

  const CommissionPaymentOption({
    required this.key,
    required this.label,
    required this.rate,
  });
}
