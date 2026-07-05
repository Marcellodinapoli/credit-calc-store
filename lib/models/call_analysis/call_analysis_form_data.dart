import 'call_analysis_form_config.dart';

/// Dati oggettivi per Analisi Strategica Pre-Contatto (senza nome debitore).
class CallAnalysisFormData {
  const CallAnalysisFormData({
    required this.creditType,
    required this.creditor,
    required this.debtorAge,
    required this.employmentStatus,
    required this.guarantorSituation,
    required this.practiceStateKey,
    this.monitoraggio,
    this.recupero,
    this.piano,
    this.saldo,
    this.consultantNotes,
  });

  final String creditType;
  final String creditor;
  final int debtorAge;
  final String employmentStatus;
  final String guarantorSituation;
  final String practiceStateKey;
  final MonitoraggioOriginatorFields? monitoraggio;
  final RecuperoCedutoFields? recupero;
  final PianoRientroFields? piano;
  final SaldoStralcioFields? saldo;
  final String? consultantNotes;

  Map<String, dynamic> toJson() {
    return {
      'creditType': creditType,
      'creditor': creditor,
      'debtorAge': debtorAge,
      'employmentStatus': employmentStatus,
      'guarantorSituation': guarantorSituation,
      'practiceStateKey': practiceStateKey,
      'practiceStateLabel':
          CallAnalysisFormConfig.labelForPracticeState(practiceStateKey),
      if (monitoraggio != null) 'monitoraggio': monitoraggio!.toJson(),
      if (recupero != null) 'recupero': recupero!.toJson(),
      if (piano != null) 'piano': piano!.toJson(),
      if (saldo != null) 'saldo': saldo!.toJson(),
      if (consultantNotes != null && consultantNotes!.trim().isNotEmpty)
        'consultantNotes': consultantNotes!.trim(),
    };
  }

  String toAnalysisText() {
    final lines = <String>[
      'ANALISI STRATEGICA PRE-CONTATTO',
      '',
      'SEZIONE FISSA',
      ..._line('Tipologia credito', creditType),
      ..._line('Creditore', creditor),
      ..._line('Età debitore', '$debtorAge'),
      ..._line('Situazione lavorativa', employmentStatus),
      ..._line('Garante', guarantorSituation),
      '',
      'STATO DELLA PRATICA',
      ..._line(
        'Stato',
        CallAnalysisFormConfig.labelForPracticeState(practiceStateKey),
      ),
    ];

    switch (practiceStateKey) {
      case CallAnalysisFormConfig.monitoraggioOriginator:
        lines.addAll(monitoraggio?.toAnalysisLines() ?? const []);
      case CallAnalysisFormConfig.recuperoCeduto:
        lines.addAll(recupero?.toAnalysisLines() ?? const []);
      case CallAnalysisFormConfig.pianoRientro:
        lines.addAll(piano?.toAnalysisLines() ?? const []);
      case CallAnalysisFormConfig.saldoStralcio:
        lines.addAll(saldo?.toAnalysisLines() ?? const []);
    }

    if (consultantNotes != null && consultantNotes!.trim().isNotEmpty) {
      lines
        ..add('')
        ..add('NOTE CONSULENTE')
        ..add(consultantNotes!.trim());
    }

    return lines.join('\n').trim();
  }

  static Iterable<String> _line(String label, String? value) sync* {
    final v = value?.trim();
    if (v == null || v.isEmpty) return;
    yield '- $label: $v';
  }
}

class MonitoraggioOriginatorFields {
  const MonitoraggioOriginatorFields({
    this.unpaidInstallments,
    this.installmentAmount,
    this.paidInstallments,
    this.totalInstallments,
    this.remainingDebt,
    this.lastPaymentDate,
    this.insolvencyHistory,
    this.defaultManagement,
  });

  final int? unpaidInstallments;
  final String? installmentAmount;
  final String? paidInstallments;
  final String? totalInstallments;
  final String? remainingDebt;
  final DateTime? lastPaymentDate;
  final String? insolvencyHistory;
  final String? defaultManagement;

  Map<String, dynamic> toJson() => {
        if (unpaidInstallments != null) 'unpaidInstallments': unpaidInstallments,
        if (_has(installmentAmount)) 'installmentAmount': installmentAmount,
        if (_has(paidInstallments)) 'paidInstallments': paidInstallments,
        if (_has(totalInstallments)) 'totalInstallments': totalInstallments,
        if (_has(remainingDebt)) 'remainingDebt': remainingDebt,
        if (lastPaymentDate != null)
          'lastPaymentDate': lastPaymentDate!.toIso8601String(),
        if (_has(insolvencyHistory)) 'insolvencyHistory': insolvencyHistory,
        if (_has(defaultManagement)) 'defaultManagement': defaultManagement,
      };

  List<String> toAnalysisLines() => [
        ...CallAnalysisFormData._line(
          'Numero rate insolute',
          unpaidInstallments?.toString(),
        ),
        ...CallAnalysisFormData._line('Importo rata', installmentAmount),
        ...CallAnalysisFormData._line('Rate pagate', paidInstallments),
        ...CallAnalysisFormData._line('Rate totali', totalInstallments),
        ...CallAnalysisFormData._line('Debito residuo', remainingDebt),
        ...CallAnalysisFormData._line(
          'Ultimo pagamento',
          _formatDate(lastPaymentDate),
        ),
        ...CallAnalysisFormData._line('Storico insolvenza', insolvencyHistory),
        ...CallAnalysisFormData._line('Gestione morosità', defaultManagement),
      ];

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;
}

class RecuperoCedutoFields {
  const RecuperoCedutoFields({
    this.assignmentNumber,
    this.remainingDebt,
    this.lastPaymentDate,
    this.recoveredAmount,
    this.recoveryHistory,
  });

  final String? assignmentNumber;
  final String? remainingDebt;
  final DateTime? lastPaymentDate;
  final String? recoveredAmount;
  final String? recoveryHistory;

  Map<String, dynamic> toJson() => {
        if (_has(assignmentNumber)) 'assignmentNumber': assignmentNumber,
        if (_has(remainingDebt)) 'remainingDebt': remainingDebt,
        if (lastPaymentDate != null)
          'lastPaymentDate': lastPaymentDate!.toIso8601String(),
        if (_has(recoveredAmount)) 'recoveredAmount': recoveredAmount,
        if (_has(recoveryHistory)) 'recoveryHistory': recoveryHistory,
      };

  List<String> toAnalysisLines() => [
        ...CallAnalysisFormData._line('Numero cessione', assignmentNumber),
        ...CallAnalysisFormData._line('Debito residuo', remainingDebt),
        ...CallAnalysisFormData._line(
          'Ultimo pagamento',
          _formatDate(lastPaymentDate),
        ),
        ...CallAnalysisFormData._line('Importo già recuperato', recoveredAmount),
        ...CallAnalysisFormData._line('Storico recupero', recoveryHistory),
      ];

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;
}

class PianoRientroFields {
  const PianoRientroFields({
    this.agreementAmount,
    this.plannedInstallments,
    this.paidInstallments,
    this.unpaidInstallments,
    this.paymentMethod,
  });

  final String? agreementAmount;
  final String? plannedInstallments;
  final String? paidInstallments;
  final String? unpaidInstallments;
  final String? paymentMethod;

  Map<String, dynamic> toJson() => {
        if (_has(agreementAmount)) 'agreementAmount': agreementAmount,
        if (_has(plannedInstallments)) 'plannedInstallments': plannedInstallments,
        if (_has(paidInstallments)) 'paidInstallments': paidInstallments,
        if (_has(unpaidInstallments)) 'unpaidInstallments': unpaidInstallments,
        if (_has(paymentMethod)) 'paymentMethod': paymentMethod,
      };

  List<String> toAnalysisLines() => [
        ...CallAnalysisFormData._line('Importo accordo', agreementAmount),
        ...CallAnalysisFormData._line('Rate previste', plannedInstallments),
        ...CallAnalysisFormData._line('Rate pagate', paidInstallments),
        ...CallAnalysisFormData._line('Rate insolute', unpaidInstallments),
        ...CallAnalysisFormData._line('Modalità pagamento', paymentMethod),
      ];

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;
}

class SaldoStralcioFields {
  const SaldoStralcioFields({
    this.originalAmount,
    this.agreedAmount,
    this.paidAmount,
    this.remainingAmount,
    this.paymentMethod,
  });

  final String? originalAmount;
  final String? agreedAmount;
  final String? paidAmount;
  final String? remainingAmount;
  final String? paymentMethod;

  Map<String, dynamic> toJson() => {
        if (_has(originalAmount)) 'originalAmount': originalAmount,
        if (_has(agreedAmount)) 'agreedAmount': agreedAmount,
        if (_has(paidAmount)) 'paidAmount': paidAmount,
        if (_has(remainingAmount)) 'remainingAmount': remainingAmount,
        if (_has(paymentMethod)) 'paymentMethod': paymentMethod,
      };

  List<String> toAnalysisLines() => [
        ...CallAnalysisFormData._line('Importo originario', originalAmount),
        ...CallAnalysisFormData._line('Importo concordato', agreedAmount),
        ...CallAnalysisFormData._line('Importo pagato', paidAmount),
        ...CallAnalysisFormData._line('Importo residuo', remainingAmount),
        ...CallAnalysisFormData._line('Modalità pagamento', paymentMethod),
      ];

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;
}

String? _formatDate(DateTime? date) {
  if (date == null) return null;
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

/// Compatibilità con il servizio esistente.
typedef CallAnalysisPracticeData = CallAnalysisFormData;
