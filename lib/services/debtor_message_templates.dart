import 'package:credit_calc_core/credit_calc_core.dart';

enum DebtorMessageKind {
  coordinate,
  sollecito,
  libero;

  String get label => switch (this) {
        DebtorMessageKind.coordinate => 'Messaggio per coordinate',
        DebtorMessageKind.sollecito => 'Messaggio per sollecito',
        DebtorMessageKind.libero => 'Messaggio libero',
      };
}

class CreditorPaymentMethodOption {
  const CreditorPaymentMethodOption({
    required this.key,
    required this.label,
    required this.coordinatesText,
  });

  final String key;
  final String label;
  final String coordinatesText;
}

class SollecitoInstallmentOption {
  const SollecitoInstallmentOption({
    required this.entryId,
    required this.companyName,
    required this.creditorName,
    required this.amount,
    required this.collectionDate,
    required this.rateIndex,
    required this.totalRates,
  });

  final String entryId;
  final String companyName;
  final String creditorName;
  final double amount;
  final DateTime collectionDate;
  final int rateIndex;
  final int totalRates;

  String get amountLabel => CommissionCollectionsHelper.formatEuro(amount);

  String get dateLabel =>
      CommissionCollectionsHelper.formatDate(collectionDate);
}

abstract final class DebtorMessageTemplates {
  DebtorMessageTemplates._();

  static String creditorDisplayName(Map<String, dynamic> data, {int? index}) {
    if (index != null) return creditorDisplayLabel(index, data);

    final clientName = (data['clientName'] ?? '').toString().trim();
    if (clientName.isNotEmpty) return clientName;

    final name = (data['name'] ?? data['displayLabel'] ?? '').toString().trim();
    return name.isNotEmpty ? name : 'Creditore';
  }

  static List<CreditorPaymentMethodOption> paymentMethodsForCreditor(
    Map<String, dynamic> creditorData,
  ) {
    final allowed = CommissionPaymentResolver.allowedMethods(creditorData);
    final payments = Map<String, dynamic>.from(
      (creditorData['paymentCoordinates'] as Map?)?.cast<String, dynamic>() ??
          {},
    );

    final options = <CreditorPaymentMethodOption>[];
    for (final entry in CommissionPaymentResolver.paymentMethodLabels.entries) {
      if (allowed[entry.key] != true) continue;
      final coordinates = _coordinatesText(entry.key, payments);
      if (coordinates.isEmpty) continue;
      options.add(
        CreditorPaymentMethodOption(
          key: entry.key,
          label: entry.value,
          coordinatesText: coordinates,
        ),
      );
    }
    return options;
  }

  static String _coordinatesText(
    String methodKey,
    Map<String, dynamic> payments,
  ) {
    String line(String label, String? value) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isEmpty) return '';
      return '$label: $trimmed';
    }

    switch (methodKey) {
      case 'bonificoBancarioPostale':
        return _joinNonEmpty([
          line('Intestazione', payments['bbHeader']?.toString()),
          line('IBAN', payments['iban']?.toString()),
        ]);
      case 'vagliaOrdinaria':
        return _joinNonEmpty([
          line('Intestazione', payments['voHeader']?.toString()),
          line('Indirizzo', payments['indVo']?.toString()),
        ]);
      case 'bollettinoPostale':
        return _joinNonEmpty([
          line('Intestazione', payments['bpHeader']?.toString()),
          line('CCP', payments['ccp']?.toString()),
          line('Indirizzo', payments['indBp']?.toString()),
        ]);
      case 'assegnoBancario':
        return line('Intestazione', payments['assHeader']?.toString());
      case 'contanti':
        return 'Pagamento in contanti';
      case 'pdrEffettiCambiari':
        return 'Piano di rientro con effetti cambiari';
      case 'pdrBollettiniPostali':
        return 'Piano di rientro con bollettini postali';
      default:
        return '';
    }
  }

  static String _joinNonEmpty(List<String> lines) =>
      lines.where((line) => line.isNotEmpty).join('\n');

  static String coordinateMessage({
    required String paymentMethodLabel,
    required String coordinatesText,
    required String installmentDetail,
  }) {
    final method = paymentMethodLabel.trim().toLowerCase();
    final detail = installmentDetail.trim();
    final detailPart = detail.isEmpty ? '...' : detail;

    return 'Gentile cliente, le invio le coordinate del $method:\n'
        '$coordinatesText\n'
        'per il pagamento della rata $detailPart.\n\n'
        'Per favore ci invii copia della ricevuta.\n\n'
        'Distinti saluti.';
  }

  static String sollecitoMessage({
    required String companyName,
    required double amount,
    required DateTime collectionDate,
  }) {
    final company = companyName.trim();
    final amountLabel = CommissionCollectionsHelper.formatEuro(amount);
    final dateLabel = CommissionCollectionsHelper.formatDate(collectionDate);

    return 'Gentile $company, le ricordiamo il pagamento della rata '
        '$amountLabel previsto il $dateLabel, appena fatto ci invii copia '
        'della ricevuta di pagamento a questo recapito.\n\n'
        'Grazie, distinti saluti.';
  }

  static String emailSubjectForKind(
    DebtorMessageKind kind, {
    String reference = '',
  }) {
    final ref = reference.trim();
    return switch (kind) {
      DebtorMessageKind.coordinate => ref.isEmpty
          ? 'Coordinate per pagamento rata'
          : 'Coordinate pagamento — $ref',
      DebtorMessageKind.sollecito => ref.isEmpty
          ? 'Sollecito pagamento rata'
          : 'Sollecito rata — $ref',
      DebtorMessageKind.libero => ref.isEmpty
          ? 'Messaggio'
          : ref,
    };
  }

  static List<SollecitoInstallmentOption> installmentsForPractice(
    List<CommissionEntryRecord> entries,
    String practiceKey,
  ) {
    final installments = entries
        .where((entry) {
          final company = CommissionCollectionsHelper.companyName(entry.data);
          if (company.isEmpty) return false;
          final creditorId = (entry.data['creditorId'] ?? '').toString();
          return '$creditorId::$company' == practiceKey;
        })
        .toList()
      ..sort((a, b) {
        final da =
            CommissionCollectionsHelper.entryDate(a.data) ?? DateTime(1970);
        final db =
            CommissionCollectionsHelper.entryDate(b.data) ?? DateTime(1970);
        return da.compareTo(db);
      });

    final total = installments.length;
    final options = <SollecitoInstallmentOption>[];
    for (var i = 0; i < installments.length; i++) {
      final entry = installments[i];
      final date = CommissionCollectionsHelper.entryDate(entry.data);
      if (date == null) continue;
      options.add(
        SollecitoInstallmentOption(
          entryId: entry.id,
          companyName: CommissionCollectionsHelper.companyName(entry.data),
          creditorName: CommissionCollectionsHelper.creditorName(entry.data),
          amount: CommissionCollectionsHelper.numField(
            entry.data,
            'amountCollected',
          ),
          collectionDate: date,
          rateIndex: i + 1,
          totalRates: total,
        ),
      );
    }
    return options;
  }
}
