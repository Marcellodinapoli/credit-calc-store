/// Dati pratica per analisi telefonata (senza nome e cognome debitore).
class CallAnalysisPracticeData {
  const CallAnalysisPracticeData({
    required this.creditor,
    required this.creditType,
    required this.installmentAmount,
    required this.unpaidInstallments,
    required this.paidInstallments,
    required this.totalInstallments,
    required this.remainingDebt,
    required this.defaultFees,
    required this.lastPaymentDate,
    required this.debtorAge,
    required this.employmentStatus,
    required this.hasCoObligor,
    required this.hasGuarantor,
    required this.lastPromiseKept,
    this.consultantNotes,
  });

  final String creditor;
  final String creditType;
  final String installmentAmount;
  final int unpaidInstallments;
  final String paidInstallments;
  final String totalInstallments;
  final String remainingDebt;
  final String defaultFees;
  final DateTime lastPaymentDate;
  final int debtorAge;
  final String employmentStatus;
  final bool hasCoObligor;
  final bool hasGuarantor;
  final bool lastPromiseKept;
  final String? consultantNotes;

  Map<String, dynamic> toJson() {
    return {
      'creditor': creditor,
      'creditType': creditType,
      'installmentAmount': installmentAmount,
      'unpaidInstallments': unpaidInstallments,
      'paidInstallments': paidInstallments,
      'totalInstallments': totalInstallments,
      'remainingDebt': remainingDebt,
      'defaultFees': defaultFees,
      'lastPaymentDate': lastPaymentDate.toIso8601String(),
      'debtorAge': debtorAge,
      'employmentStatus': employmentStatus,
      'hasCoObligor': hasCoObligor,
      'hasGuarantor': hasGuarantor,
      'lastPromiseKept': lastPromiseKept,
      if (consultantNotes != null && consultantNotes!.trim().isNotEmpty)
        'consultantNotes': consultantNotes!.trim(),
    };
  }

  String toAnalysisText() {
    final date =
        '${lastPaymentDate.day.toString().padLeft(2, '0')}/'
        '${lastPaymentDate.month.toString().padLeft(2, '0')}/'
        '${lastPaymentDate.year}';
    final buffer = StringBuffer()
      ..writeln('PRATICA')
      ..writeln('- Creditore: $creditor')
      ..writeln('- Tipologia credito: $creditType')
      ..writeln('- Importo rata: $installmentAmount')
      ..writeln('- Numero rate insolute: $unpaidInstallments')
      ..writeln('- Numero rate pagate: $paidInstallments')
      ..writeln('- Numero rate totali: $totalInstallments')
      ..writeln('- Debito residuo: $remainingDebt')
      ..writeln('- Morosità/spese: $defaultFees')
      ..writeln('- Data ultimo pagamento: $date')
      ..writeln()
      ..writeln('DEBITORE (senza nome e cognome)')
      ..writeln('- Età: $debtorAge')
      ..writeln('- Stato occupazionale: $employmentStatus')
      ..writeln()
      ..writeln('GARANZIE E RISCHIO')
      ..writeln('- Coobbligato: ${hasCoObligor ? 'Sì' : 'No'}')
      ..writeln('- Garante: ${hasGuarantor ? 'Sì' : 'No'}')
      ..writeln()
      ..writeln('STORICO RECUPERO')
      ..writeln(
        '- Ultima promessa mantenuta: ${lastPromiseKept ? 'Sì' : 'No'}',
      );
    if (consultantNotes != null && consultantNotes!.trim().isNotEmpty) {
      buffer.writeln('- Note del consulente: ${consultantNotes!.trim()}');
    }
    return buffer.toString().trim();
  }

  static const creditTypes = [
    'Finanziamento personale',
    'Prestito rateale',
    'Carta di credito',
    'Mutuo',
    'Leasing',
    'Altro',
  ];

  static const employmentStatuses = [
    'Dipendente',
    'Autonomo',
    'Disoccupato',
    'Pensionato',
    'Altro',
  ];
}
