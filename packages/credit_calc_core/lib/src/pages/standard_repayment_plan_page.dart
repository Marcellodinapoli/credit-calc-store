import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/date_month_utils.dart';
import '../core/euro_format.dart';
import '../core/firestore_user_scope.dart';
import '../core/theme/app_card_theme.dart';
import '../core/theme/app_form_fields.dart';
import '../core/theme/project_colors.dart';
import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

import 'commission_export_dialog.dart';
import 'repayment_plan_commission_export.dart';

const _maxPlanScheduleIterations = 2400;

/// Piano di rientro — creditori da impostazioni (Firestore `creditors`).
class StandardRepaymentPlanPage extends StatefulWidget {
  const StandardRepaymentPlanPage({super.key});

  @override
  State<StandardRepaymentPlanPage> createState() =>
      _StandardRepaymentPlanPageState();
}

class _PdrBand {
  final int from;
  final int to;
  final int installments;

  const _PdrBand({
    required this.from,
    required this.to,
    required this.installments,
  });
}

/// Modalità di ripartizione delle dilazioni.
enum _RepaymentSplitMode {
  /// n−1 importi uguali in euro interi + ultima rata di conguaglio.
  lastAdjustment,

  /// Tutte le dilazioni dello stesso importo; totale ≤ debito (può essere leggermente inferiore).
  allEqual,
}

class _RepaymentInstallmentPlan {
  final _RepaymentSplitMode mode;
  final int installmentCount;
  final int equalCount;
  final double equalAmount;
  final double finalAmount;
  final double netAmountOriginal;
  final bool cappedToMax;

  const _RepaymentInstallmentPlan({
    required this.mode,
    required this.installmentCount,
    required this.equalCount,
    required this.equalAmount,
    required this.finalAmount,
    required this.netAmountOriginal,
    required this.cappedToMax,
  });

  double get totalRecovered {
    if (mode == _RepaymentSplitMode.lastAdjustment) {
      // Conguaglio: l'ultima rata assorbe i centesimi → totale = importo da recuperare.
      return (netAmountOriginal * 100).round() / 100;
    }
    if (installmentCount <= 1) return finalAmount;
    return installmentCount * equalAmount;
  }

  bool get allInstallmentsSameAmount =>
      mode == _RepaymentSplitMode.allEqual ||
      (equalAmount - finalAmount).abs() < 0.005;

  List<String> structureLines(String paymentMethod) {
    final isBollettino = paymentMethod == 'Bollettino';
    final plural = isBollettino ? 'bollettini' : 'effetti';
    final singular = isBollettino ? 'bollettino' : 'effetto';
    final amountText = _formatInstallmentLineAmount(equalAmount);

    if (installmentCount <= 1) {
      return ['1 $singular da ${EuroFormat.format(finalAmount)}'];
    }

    if (allInstallmentsSameAmount) {
      final lines = <String>['$installmentCount $plural da $amountText'];
      if (totalRecovered + 0.009 < netAmountOriginal) {
        lines.add(
          'Totale recupero ${EuroFormat.format(totalRecovered)} '
          '(importo netto ${EuroFormat.format(netAmountOriginal)})',
        );
      }
      return lines;
    }

    final finalText = EuroFormat.format(finalAmount);
    return [
      '$equalCount $plural da $amountText',
      '1 $singular da $finalText',
    ];
  }

  static int? installmentCountForDesiredAmount({
    required double netAmount,
    required double desiredInstallment,
  }) {
    if (netAmount <= 0 || desiredInstallment <= 0) return null;
    return (netAmount / desiredInstallment).ceil().clamp(1, 99999);
  }

  static String _formatInstallmentLineAmount(double amount) {
    final cents = (amount * 100).round();
    if (cents % 100 == 0) {
      return EuroFormat.formatWholeEuro(amount);
    }
    return EuroFormat.format(amount);
  }

  /// Conguaglio: (n−1) rate all'importo scelto + ultima rata con i centesimi restanti.
  static _RepaymentInstallmentPlan? _buildLastAdjustmentPlan({
    required int n,
    required int totalCents,
    required double netAmount,
    required double minRata,
    required bool capped,
    double? chosenInstallmentAmount,
  }) {
    if (n < 1) return null;

    if (n == 1) {
      final single = totalCents / 100;
      if (single + 1e-9 < minRata) return null;
      return _RepaymentInstallmentPlan(
        mode: _RepaymentSplitMode.lastAdjustment,
        installmentCount: 1,
        equalCount: 0,
        equalAmount: 0,
        finalAmount: single,
        netAmountOriginal: netAmount,
        cappedToMax: capped,
      );
    }

    final int equalCents;
    if (chosenInstallmentAmount != null && chosenInstallmentAmount > 0) {
      equalCents = (chosenInstallmentAmount * 100).round();
    } else {
      equalCents = (netAmount / n).floor() * 100;
    }

    if (equalCents <= 0) return null;

    final lastCents = totalCents - equalCents * (n - 1);
    if (lastCents <= 0) return null;

    final equalAmount = equalCents / 100;
    final lastAmount = lastCents / 100;
    final recoveredCents = equalCents * (n - 1) + lastCents;

    if (equalAmount + 1e-9 < minRata) return null;
    if (lastAmount + 1e-9 < minRata) return null;

    if (recoveredCents != totalCents) return null;

    return _RepaymentInstallmentPlan(
      mode: _RepaymentSplitMode.lastAdjustment,
      installmentCount: n,
      equalCount: n - 1,
      equalAmount: equalAmount,
      finalAmount: lastAmount,
      netAmountOriginal: netAmount,
      cappedToMax: capped,
    );
  }

  /// Bimestrale/trimestrale: tutte le dilazioni uguali alla rata mensile;
  /// il totale recuperato può essere inferiore all'importo originario.
  static _RepaymentInstallmentPlan? buildAllEqualWithFixedMonthlyRate({
    required double netAmount,
    required double monthlyPayment,
    required double minInstallment,
  }) {
    final minRata = minInstallment > 0 ? minInstallment : 0.01;
    if (monthlyPayment + 1e-9 < minRata) return null;

    if (netAmount + 1e-9 < monthlyPayment) {
      if (netAmount + 1e-9 < minRata) return null;
      return _RepaymentInstallmentPlan(
        mode: _RepaymentSplitMode.allEqual,
        installmentCount: 1,
        equalCount: 1,
        equalAmount: netAmount,
        finalAmount: netAmount,
        netAmountOriginal: netAmount,
        cappedToMax: false,
      );
    }

    final n = (netAmount / monthlyPayment).floor();
    if (n < 1) return null;
    if (n > _maxPlanScheduleIterations) return null;

    return _RepaymentInstallmentPlan(
      mode: _RepaymentSplitMode.allEqual,
      installmentCount: n,
      equalCount: n,
      equalAmount: monthlyPayment,
      finalAmount: monthlyPayment,
      netAmountOriginal: netAmount,
      cappedToMax: false,
    );
  }

  static String? failureReasonForAllEqualMonthlyRate({
    required String planLabel,
    required double netAmount,
    required double monthlyPayment,
    required double minInstallment,
  }) {
    final minRata = minInstallment > 0 ? minInstallment : 0.01;
    if (monthlyPayment + 1e-9 < minRata) {
      return '$planLabel: la rata mensile ${EuroFormat.format(monthlyPayment)} '
          'è inferiore alla rata minima del creditore '
          '(${EuroFormat.format(minRata)}).';
    }

    if (netAmount + 1e-9 < minRata) {
      return '$planLabel: l\'importo ${EuroFormat.format(netAmount)} è '
          'inferiore alla rata minima (${EuroFormat.format(minRata)}).';
    }

    return null;
  }

  /// Dilazioni necessarie con rate tutte uguali, rispettando il minimo rata.
  static int? installmentCountForMinAmount({
    required double netAmount,
    required double minInstallment,
  }) {
    if (netAmount <= 0) return null;

    final minRata = minInstallment > 0 ? minInstallment : 0.01;
    if (netAmount + 1e-9 < minRata) return null;

    var n = (netAmount / minRata).floor();
    if (n < 1) n = 1;

    while (n > 1 && (netAmount / n).floor() + 1e-9 < minRata) {
      n--;
    }

    if ((netAmount / n).floor() + 1e-9 < minRata) return null;
    return n;
  }

  /// Conguaglio automatico: (n−1) rate uguali + ultima che chiude al centesimo,
  /// entrambe non inferiori al minimo creditore.
  static int? installmentCountForLastAdjustment({
    required double netAmount,
    required double minInstallment,
  }) {
    if (netAmount <= 0) return null;

    final minRata = minInstallment > 0 ? minInstallment : 0.01;
    final minCents = (minRata * 100).round();
    final totalCents = (netAmount * 100).round();
    if (totalCents < minCents) return null;

    final nStart = (netAmount / minRata).floor();
    for (var n = nStart < 1 ? 1 : nStart; n >= 1; n--) {
      if (n == 1) {
        if (totalCents >= minCents) return 1;
        continue;
      }

      final equalCents = (netAmount / n).floor() * 100;
      if (equalCents < minCents) continue;

      final lastCents = totalCents - equalCents * (n - 1);
      if (lastCents < minCents || lastCents <= 0) continue;
      if (equalCents * (n - 1) + lastCents != totalCents) continue;
      return n;
    }
    return null;
  }

  /// Conguaglio manuale per importo rata desiderato.
  static int? installmentCountForDesiredLastAdjustment({
    required double netAmount,
    required double desiredInstallment,
    required double minInstallment,
  }) {
    if (netAmount <= 0 || desiredInstallment <= 0) return null;

    final minRata = minInstallment > 0 ? minInstallment : 0.01;
    if (desiredInstallment + 1e-9 < minRata) return null;

    final totalCents = (netAmount * 100).round();
    final equalCents = (desiredInstallment * 100).round();
    final minCents = (minRata * 100).round();
    if (equalCents < minCents) return null;

    if (totalCents <= equalCents) {
      return totalCents >= minCents ? 1 : null;
    }

    final n = ((totalCents - minCents) / equalCents).floor() + 1;
    if (n < 1) return null;

    final lastCents = totalCents - equalCents * (n - 1);
    if (lastCents < minCents || lastCents <= 0) return null;
    if (equalCents * (n - 1) + lastCents != totalCents) return null;
    return n;
  }

  static ({int n, bool capped})? _resolveInstallmentCount({
    required double netAmount,
    required int maxInstallments,
    required double minInstallment,
    required _RepaymentSplitMode mode,
  }) {
    if (maxInstallments <= 0 || netAmount <= 0) return null;

    final minRata = minInstallment > 0 ? minInstallment : 0.01;
    final provisionalInstallment = (netAmount / maxInstallments).floor();

    if (provisionalInstallment + 1e-9 >= minRata) {
      return (n: maxInstallments, capped: false);
    }

    final n = mode == _RepaymentSplitMode.lastAdjustment
        ? installmentCountForLastAdjustment(
            netAmount: netAmount,
            minInstallment: minInstallment,
          )
        : installmentCountForMinAmount(
            netAmount: netAmount,
            minInstallment: minInstallment,
          );
    if (n == null) return null;

    if (n > maxInstallments) return null;

    return (n: n, capped: true);
  }

  static _RepaymentInstallmentPlan? build({
    required double netAmount,
    required int maxInstallments,
    required double minInstallment,
    required _RepaymentSplitMode mode,
    int? fixedInstallmentCount,
    double? chosenInstallmentAmount,
  }) {
    final minRata = minInstallment > 0 ? minInstallment : 0.01;
    final ({int n, bool capped})? resolved;
    if (fixedInstallmentCount != null) {
      final n = fixedInstallmentCount;
      if (n < 1) return null;
      // Con il conguaglio la rata media può essere sotto il minimo: conta l'ultima rata.
      if (mode != _RepaymentSplitMode.lastAdjustment &&
          netAmount / n + 1e-9 < minRata) {
        return null;
      }
      resolved = (n: n, capped: false);
    } else {
      resolved = _resolveInstallmentCount(
        netAmount: netAmount,
        maxInstallments: maxInstallments,
        minInstallment: minInstallment,
        mode: mode,
      );
    }
    if (resolved == null) return null;

    final n = resolved.n;
    final capped = fixedInstallmentCount == null && resolved.capped;
    final totalCents = (netAmount * 100).round();

    if (mode == _RepaymentSplitMode.lastAdjustment) {
      return _buildLastAdjustmentPlan(
        n: n,
        totalCents: totalCents,
        netAmount: netAmount,
        minRata: minRata,
        capped: capped,
        chosenInstallmentAmount: chosenInstallmentAmount,
      );
    }

    if (n == 1) {
      final single = totalCents / 100;
      if (single + 1e-9 < minRata) return null;
      return _RepaymentInstallmentPlan(
        mode: mode,
        installmentCount: 1,
        equalCount: 0,
        equalAmount: 0,
        finalAmount: single,
        netAmountOriginal: netAmount,
        cappedToMax: capped,
      );
    }

    final wholeEuro = (netAmount / n).floor();
    if (wholeEuro + 1e-9 < minRata) return null;

    final perInstallment = wholeEuro.toDouble();
    final totalRecovered = n * perInstallment;
    if (totalRecovered - netAmount > 0.009) return null;

    return _RepaymentInstallmentPlan(
      mode: mode,
      installmentCount: n,
      equalCount: n,
      equalAmount: perInstallment,
      finalAmount: perInstallment,
      netAmountOriginal: netAmount,
      cappedToMax: capped,
    );
  }

  List<double> get installmentAmountsList {
    if (installmentCount <= 1) return [finalAmount];
    if (mode == _RepaymentSplitMode.allEqual) {
      return List<double>.filled(installmentCount, equalAmount);
    }
    return [
      ...List<double>.filled(equalCount, equalAmount),
      finalAmount,
    ];
  }

  static _RepaymentInstallmentPlan? fromRecordedPayments({
    required List<double> payments,
    required double netAmount,
  }) {
    if (payments.isEmpty) return null;

    final recovered = payments.fold<double>(0, (total, p) => total + p);
    final count = payments.length;
    final allSame =
        payments.every((p) => (p - payments.first).abs() < 0.009);

    if (allSame) {
      return _RepaymentInstallmentPlan(
        mode: _RepaymentSplitMode.allEqual,
        installmentCount: count,
        equalCount: count,
        equalAmount: payments.first,
        finalAmount: payments.first,
        netAmountOriginal: netAmount,
        cappedToMax: false,
      );
    }

    return _RepaymentInstallmentPlan(
      mode: _RepaymentSplitMode.allEqual,
      installmentCount: count,
      equalCount: count,
      equalAmount: recovered / count,
      finalAmount: payments.last,
      netAmountOriginal: netAmount,
      cappedToMax: false,
    );
  }
}

/// Fase iniziale a rata scelta dal cliente (piano modulato).
class _ModulatedPhase {
  final int months;
  final double monthlyAmount;

  const _ModulatedPhase({
    required this.months,
    required this.monthlyAmount,
  });

  double get totalRecovered => months * monthlyAmount;
}

/// Piano modulato: fino a 3 fasi personalizzate + dilazione del residuo (logica mensile).
class _ModulatedRepaymentPlanResult {
  final List<_ModulatedPhase> phases;
  final double netAmountOriginal;
  final double modulatedRecovered;
  final double residualDebt;
  final int modulatedMonths;
  final int finalInstallmentCount;
  final _RepaymentInstallmentPlan finalPlan;
  final DateTime planStartDate;

  const _ModulatedRepaymentPlanResult({
    required this.phases,
    required this.netAmountOriginal,
    required this.modulatedRecovered,
    required this.residualDebt,
    required this.modulatedMonths,
    required this.finalInstallmentCount,
    required this.finalPlan,
    required this.planStartDate,
  });

  static String _dateRangeInParentheses(
    DateTime from,
    DateTime to,
    String Function(DateTime) formatDate,
  ) {
    return 'da ${formatDate(from)} – al ${formatDate(to)}';
  }

  int get totalMonths => modulatedMonths + finalInstallmentCount;

  int get totalInstallmentCount => modulatedMonths + finalPlan.installmentCount;

  double get totalRecovered => modulatedRecovered + finalPlan.totalRecovered;

  List<String> _residualInstallmentSummaryLines(
    String paymentMethod,
    String Function(DateTime) formatDate,
    int monthOffsetAfterPhases,
  ) {
    final plan = finalPlan;
    final isBollettino = paymentMethod == 'Bollettino';
    final plural = isBollettino ? 'bollettini' : 'cambiali';
    final singular = isBollettino ? 'bollettino' : 'cambiale';

    if (plan.installmentCount <= 0) return const [];

    var cursor = monthOffsetAfterPhases;

    DateTime rangeStart(int count) =>
        addMonthsSameCalendarDay(planStartDate, cursor);

    DateTime rangeEnd(int count) => addMonthsSameCalendarDay(
          planStartDate,
          cursor + count - 1,
        );

    if (plan.allInstallmentsSameAmount) {
      final count = plan.installmentCount;
      final amount =
          plan.equalAmount > 0 ? plan.equalAmount : plan.finalAmount;
      final label = count == 1 ? singular : plural;
      final range = _dateRangeInParentheses(
        rangeStart(count),
        rangeEnd(count),
        formatDate,
      );
      return [
        '$count $label × ${EuroFormat.format(amount)} ($range)',
      ];
    }

    final lines = <String>[];
    if (plan.equalCount > 0) {
      final count = plan.equalCount;
      final range = _dateRangeInParentheses(
        rangeStart(count),
        rangeEnd(count),
        formatDate,
      );
      lines.add(
        '$count $plural × ${EuroFormat.format(plan.equalAmount)} ($range)',
      );
      cursor += count;
    }
    final finalCount = plan.installmentCount - plan.equalCount;
    if (finalCount > 0) {
      final label = finalCount == 1 ? singular : plural;
      final range = _dateRangeInParentheses(
        rangeStart(finalCount),
        rangeEnd(finalCount),
        formatDate,
      );
      lines.add(
        '$finalCount $label × ${EuroFormat.format(plan.finalAmount)} ($range)',
      );
    }
    return lines;
  }

  List<String> phaseSummaryLines(
    String paymentMethod,
    String Function(DateTime) formatDate,
  ) {
    final isBollettino = paymentMethod == 'Bollettino';
    final plural = isBollettino ? 'bollettini' : 'cambiali';
    final singular = isBollettino ? 'bollettino' : 'cambiale';
    final lines = <String>[];
    var monthOffset = 0;

    for (final phase in phases) {
      final label = phase.months == 1 ? singular : plural;
      final phaseStart =
          addMonthsSameCalendarDay(planStartDate, monthOffset);
      final phaseEnd = addMonthsSameCalendarDay(
        planStartDate,
        monthOffset + phase.months - 1,
      );
      final range =
          _dateRangeInParentheses(phaseStart, phaseEnd, formatDate);
      lines.add(
        '${phase.months} $label × ${EuroFormat.format(phase.monthlyAmount)} '
        '($range)',
      );
      monthOffset += phase.months;
    }
    lines.addAll(
      _residualInstallmentSummaryLines(
        paymentMethod,
        formatDate,
        monthOffset,
      ),
    );
    return lines;
  }
}

/// Singolo pagamento nel calendario unificato (una mensilità cliente).
class _ScheduledClientPayment {
  final DateTime date;
  final String practiceLabel;
  final double amount;
  final int practiceInstallmentIndex;

  const _ScheduledClientPayment({
    required this.date,
    required this.practiceLabel,
    required this.amount,
    required this.practiceInstallmentIndex,
  });
}

/// Debito pratica per piani bimestrale/trimestrale.
typedef _PracticeDebt = ({
  String label,
  double netAmount,
  double accontoAmount,
});

/// Una fase di dilazione nel riepilogo card (es. quota su 3 / 2 / 1 piani).
class _PracticeDilazionePhase {
  final int paymentCount;
  final double installmentAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String rateFrequencyLabel;

  const _PracticeDilazionePhase({
    required this.paymentCount,
    required this.installmentAmount,
    required this.startDate,
    required this.endDate,
    required this.rateFrequencyLabel,
  });
}

List<_PracticeDilazionePhase> _buildDilazionePhasesFromSegments({
  required List<DateTime> triDates,
  required List<double> triAmounts,
  required List<DateTime> biDates,
  required List<double> biAmounts,
  required List<DateTime> soloDates,
  required List<double> soloAmounts,
}) {
  final phases = <_PracticeDilazionePhase>[];

  void addPhase(
    List<DateTime> dates,
    List<double> amounts,
    String frequency,
  ) {
    if (dates.isEmpty || amounts.isEmpty) return;
    final displayAmount = amounts.reduce((a, b) => a > b ? a : b);
    phases.add(
      _PracticeDilazionePhase(
        paymentCount: dates.length,
        installmentAmount: displayAmount,
        startDate: dates.first,
        endDate: dates.last,
        rateFrequencyLabel: frequency,
      ),
    );
  }

  addPhase(triDates, triAmounts, 'trimestrali');
  addPhase(biDates, biAmounts, 'bimestrali');
  addPhase(soloDates, soloAmounts, 'mensili');
  return phases;
}

/// Piano di rientro di una pratica (A, B o C).
class _PracticePdrSchedule {
  final int planNumber;
  final String label;
  final double netAmount;
  final double accontoAmount;
  final _RepaymentInstallmentPlan plan;
  final _PdrBand? band;
  final DateTime startDate;
  final DateTime endDate;
  /// Fase con 3 pratiche attive: una rata ogni 3 mesi per pratica (solo trimestrale).
  final int trimestralCalendarMonths;
  final int trimestralPaymentCount;
  /// Fase con 2 pratiche attive: una rata ogni 2 mesi per pratica.
  final int bimestralCalendarMonths;
  final int bimestralPaymentCount;
  /// Fase con 1 pratica residua: rata ogni mese.
  final int soloCalendarMonths;
  final int soloPaymentCount;
  /// Rate effettive (quota mensile variabile nel piano mensile multi-pratica).
  final List<double>? paymentAmounts;
  final List<_PracticeDilazionePhase> dilazionePhases;

  const _PracticePdrSchedule({
    required this.planNumber,
    required this.label,
    required this.netAmount,
    this.accontoAmount = 0,
    required this.plan,
    required this.band,
    required this.startDate,
    required this.endDate,
    this.trimestralCalendarMonths = 0,
    this.trimestralPaymentCount = 0,
    this.bimestralCalendarMonths = 0,
    this.bimestralPaymentCount = 0,
    this.soloCalendarMonths = 0,
    this.soloPaymentCount = 0,
    this.paymentAmounts,
    this.dilazionePhases = const [],
  });

  double get totalRecovered => plan.totalRecovered;
}

/// Risultato bimestrale / trimestrale: più PDR con rata mensile unica alternata.
class _MultiPracticePlanResult {
  final double monthlyClientPayment;
  final List<_PracticePdrSchedule> practices;
  final List<_ScheduledClientPayment> calendar;
  final DateTime overallEndDate;
  final List<String> phaseDescriptions;
  final bool monthlyParallel;

  const _MultiPracticePlanResult({
    required this.monthlyClientPayment,
    required this.practices,
    required this.calendar,
    required this.overallEndDate,
    required this.phaseDescriptions,
    this.monthlyParallel = false,
  });

  double get totalRecovered =>
      practices.fold(0.0, (total, p) => total + p.plan.totalRecovered);

  static ({_MultiPracticePlanResult? result, String? errorMessage}) tryBuild({
    required List<_PracticeDebt> practiceDebts,
    required double monthlyPayment,
    required DateTime startDate,
    required double minInstallment,
    required List<_PdrBand> pdrBands,
    bool monthlyParallel = false,
  }) {
    final built = monthlyParallel
        ? buildMonthlyParallel(
            practiceDebts: practiceDebts,
            monthlyPayment: monthlyPayment,
            startDate: startDate,
            minInstallment: minInstallment,
            pdrBands: pdrBands,
          )
        : build(
            practiceDebts: practiceDebts,
            monthlyPayment: monthlyPayment,
            startDate: startDate,
            minInstallment: minInstallment,
            pdrBands: pdrBands,
          );
    if (built != null) return (result: built, errorMessage: null);

    if (monthlyParallel && practiceDebts.isNotEmpty) {
      final minRata = minInstallment > 0 ? minInstallment : 0.01;
      final n = practiceDebts.length;
      final share = monthlyPayment / n;
      if (share + 1e-9 < minRata) {
        return (
          result: null,
          errorMessage:
              'Con $n piani la quota mensile (${EuroFormat.format(share)}) '
              'è inferiore alla rata minima del creditore '
              '(${EuroFormat.format(minRata)}). Aumenta l\'importo mensile disponibile.',
        );
      }
    }

    final sorted = [...practiceDebts]..sort(_comparePracticeNetAmount);
    for (var i = 0; i < sorted.length; i++) {
      final label = 'Piano di rientro ${i + 1}';
      final reason = _RepaymentInstallmentPlan.failureReasonForAllEqualMonthlyRate(
        planLabel: label,
        netAmount: sorted[i].netAmount,
        monthlyPayment: monthlyPayment,
        minInstallment: minInstallment,
      );
      if (reason != null) return (result: null, errorMessage: reason);
    }

    return (
      result: null,
      errorMessage:
          'Impossibile strutturare i piani con rata '
          '${EuroFormat.format(monthlyPayment)}.',
    );
  }

  static _MultiPracticePlanResult? build({
    required List<_PracticeDebt> practiceDebts,
    required double monthlyPayment,
    required DateTime startDate,
    required double minInstallment,
    required List<_PdrBand> pdrBands,
  }) {
    if (practiceDebts.isEmpty || monthlyPayment <= 0) return null;

    final minRata = minInstallment > 0 ? minInstallment : 0.01;
    if (monthlyPayment + 1e-9 < minRata) return null;

    // Sempre dal debito netto più piccolo al più grande (ordine campi ignorato).
    final sortedDebts = [...practiceDebts]
      ..sort(_comparePracticeNetAmount);
    final numberedDebts = <_PracticeDebt>[
      for (var i = 0; i < sortedDebts.length; i++)
        (
          label: 'Piano di rientro ${i + 1}',
          netAmount: sortedDebts[i].netAmount,
          accontoAmount: sortedDebts[i].accontoAmount,
        ),
    ];

    _PdrBand? bandFor(double amount) {
      final value = amount.round();
      for (final band in pdrBands) {
        if (value >= band.from && value <= band.to) return band;
      }
      return null;
    }

    final built = <({
      String label,
      double net,
      double acconto,
      _RepaymentInstallmentPlan plan,
      _PdrBand? band,
      int planNumber,
    })>[];

    for (var i = 0; i < numberedDebts.length; i++) {
      final debt = numberedDebts[i];
      if (debt.netAmount <= 0) return null;
      final band = bandFor(debt.netAmount);
      final plan = _RepaymentInstallmentPlan.buildAllEqualWithFixedMonthlyRate(
        netAmount: debt.netAmount,
        monthlyPayment: monthlyPayment,
        minInstallment: minInstallment,
      );
      if (plan == null) return null;
      built.add((
        label: debt.label,
        net: debt.netAmount,
        acconto: debt.accontoAmount,
        plan: plan,
        band: band,
        planNumber: i + 1,
      ));
    }

    final amountsByPractice =
        built.map((b) => b.plan.installmentAmountsList).toList();
    final indices = List<int>.filled(built.length, 0);
    final paymentDates = List<List<DateTime>>.generate(
      built.length,
      (_) => <DateTime>[],
    );
    final trimestralMonthOffsets = List<List<int>>.generate(
      built.length,
      (_) => <int>[],
    );
    final bimestralMonthOffsets = List<List<int>>.generate(
      built.length,
      (_) => <int>[],
    );
    final soloMonthOffsets = List<List<int>>.generate(
      built.length,
      (_) => <int>[],
    );
    final triDates = List.generate(built.length, (_) => <DateTime>[]);
    final triAmounts = List.generate(built.length, (_) => <double>[]);
    final biDates = List.generate(built.length, (_) => <DateTime>[]);
    final biAmounts = List.generate(built.length, (_) => <double>[]);
    final soloDates = List.generate(built.length, (_) => <DateTime>[]);
    final soloAmounts = List.generate(built.length, (_) => <double>[]);
    final calendar = <_ScheduledClientPayment>[];
    final phaseDescriptions = <String>[];
    String? lastPhase;

    var monthOffset = 0;
    var rotation = 0;
    while (true) {
      final active = <int>[];
      for (var i = 0; i < built.length; i++) {
        if (indices[i] < amountsByPractice[i].length) active.add(i);
      }
      if (active.isEmpty) break;
      if (monthOffset > _maxPlanScheduleIterations) return null;

      final phase = switch (active.length) {
        1 => 'Pagamento mensile sulla pratica residua '
            '(${built[active.first].label})',
        2 => 'Rotazione bimestrale su 2 pratiche '
            '(${built[active[0]].label} ↔ ${built[active[1]].label})',
        3 => 'Rotazione trimestrale su 3 pratiche '
            '(${built[active[0]].label} → ${built[active[1]].label} → '
            '${built[active[2]].label})',
        _ => 'Rotazione alternata su ${active.length} pratiche '
            '(${active.map((i) => built[i].label).join(' → ')})',
      };
      if (phase != lastPhase) {
        phaseDescriptions.add(phase);
        lastPhase = phase;
      }

      final pick = active[rotation % active.length];
      final installmentIdx = indices[pick];
      final amount = amountsByPractice[pick][installmentIdx];
      final date = addMonthsSameCalendarDay(startDate, monthOffset);

      calendar.add(
        _ScheduledClientPayment(
          date: date,
          practiceLabel: built[pick].label,
          amount: amount,
          practiceInstallmentIndex: installmentIdx + 1,
        ),
      );
      paymentDates[pick].add(date);
      switch (active.length) {
        case 1:
          soloMonthOffsets[pick].add(monthOffset);
          soloDates[pick].add(date);
          soloAmounts[pick].add(amount);
        case 2:
          bimestralMonthOffsets[pick].add(monthOffset);
          biDates[pick].add(date);
          biAmounts[pick].add(amount);
        default:
          trimestralMonthOffsets[pick].add(monthOffset);
          triDates[pick].add(date);
          triAmounts[pick].add(amount);
      }
      indices[pick]++;
      monthOffset++;
      rotation++;
    }

    int calendarMonthsSpan(List<int> offsets) {
      if (offsets.isEmpty) return 0;
      final sorted = [...offsets]..sort();
      return sorted.last - sorted.first + 1;
    }

    final practices = <_PracticePdrSchedule>[];
    for (var i = 0; i < built.length; i++) {
      final dates = paymentDates[i];
      final triOffsets = trimestralMonthOffsets[i];
      final biOffsets = bimestralMonthOffsets[i];
      final soloOffsets = soloMonthOffsets[i];
      practices.add(
        _PracticePdrSchedule(
          planNumber: built[i].planNumber,
          label: built[i].label,
          netAmount: built[i].net,
          accontoAmount: built[i].acconto,
          plan: built[i].plan,
          band: built[i].band,
          startDate: dates.isEmpty ? startDate : dates.first,
          endDate: dates.isEmpty ? startDate : dates.last,
          trimestralCalendarMonths: calendarMonthsSpan(triOffsets),
          trimestralPaymentCount: triOffsets.length,
          bimestralCalendarMonths: calendarMonthsSpan(biOffsets),
          bimestralPaymentCount: biOffsets.length,
          soloCalendarMonths: calendarMonthsSpan(soloOffsets),
          soloPaymentCount: soloOffsets.length,
          dilazionePhases: _buildDilazionePhasesFromSegments(
            triDates: triDates[i],
            triAmounts: triAmounts[i],
            biDates: biDates[i],
            biAmounts: biAmounts[i],
            soloDates: soloDates[i],
            soloAmounts: soloAmounts[i],
          ),
        ),
      );
    }

    practices.sort(_comparePracticeScheduleByNet);

    return _MultiPracticePlanResult(
      monthlyClientPayment: monthlyPayment,
      practices: practices,
      calendar: calendar,
      overallEndDate: calendar.isEmpty
          ? startDate
          : calendar.last.date,
      phaseDescriptions: phaseDescriptions,
    );
  }

  /// Mensile multi-pratica: ogni mese l'importo disponibile è ripartito in parti
  /// uguali tra i piani ancora aperti; tutti pagano nello stesso mese calendario.
  static _MultiPracticePlanResult? buildMonthlyParallel({
    required List<_PracticeDebt> practiceDebts,
    required double monthlyPayment,
    required DateTime startDate,
    required double minInstallment,
    required List<_PdrBand> pdrBands,
  }) {
    if (practiceDebts.isEmpty || monthlyPayment <= 0) return null;

    final minRata = minInstallment > 0 ? minInstallment : 0.01;
    final sortedDebts = [...practiceDebts]..sort(_comparePracticeNetAmount);
    final n = sortedDebts.length;
    if (n < 2) return null;

    if (monthlyPayment / n + 1e-9 < minRata) return null;

    _PdrBand? bandFor(double amount) {
      final value = amount.round();
      for (final band in pdrBands) {
        if (value >= band.from && value <= band.to) return band;
      }
      return null;
    }

    final numberedDebts = <_PracticeDebt>[
      for (var i = 0; i < sortedDebts.length; i++)
        (
          label: 'Piano di rientro ${i + 1}',
          netAmount: sortedDebts[i].netAmount,
          accontoAmount: sortedDebts[i].accontoAmount,
        ),
    ];

    final balances = numberedDebts.map((d) => d.netAmount).toList();
    if (balances.any((b) => b <= 0)) return null;

    final paymentAmounts = List.generate(n, (_) => <double>[]);
    final paymentDates = List.generate(n, (_) => <DateTime>[]);
    final trimestralMonthOffsets = List.generate(n, (_) => <int>[]);
    final bimestralMonthOffsets = List.generate(n, (_) => <int>[]);
    final soloMonthOffsets = List.generate(n, (_) => <int>[]);
    final triDates = List.generate(n, (_) => <DateTime>[]);
    final triAmounts = List.generate(n, (_) => <double>[]);
    final biDates = List.generate(n, (_) => <DateTime>[]);
    final biAmounts = List.generate(n, (_) => <double>[]);
    final soloDates = List.generate(n, (_) => <DateTime>[]);
    final soloAmounts = List.generate(n, (_) => <double>[]);
    final installmentIndices = List.filled(n, 0);
    final calendar = <_ScheduledClientPayment>[];
    final phaseDescriptions = <String>[];
    String? lastPhase;

    var monthOffset = 0;
    while (true) {
      final active = <int>[];
      for (var i = 0; i < n; i++) {
        if (balances[i] > 0.009) active.add(i);
      }
      if (active.isEmpty) break;
      if (monthOffset > _maxPlanScheduleIterations) return null;

      final share = monthlyPayment / active.length;
      if (share + 1e-9 < minRata) return null;

      final phase = switch (active.length) {
        1 =>
          'Importo mensile intero su ${numberedDebts[active.first].label} (chiusura)',
        2 =>
          'Quota mensile ripartita su 2 piani '
          '(${numberedDebts[active[0]].label} + ${numberedDebts[active[1]].label})',
        3 => 'Quota mensile ripartita su 3 piani attivi',
        _ => 'Quota ripartita su ${active.length} piani attivi',
      };
      if (phase != lastPhase) {
        phaseDescriptions.add(phase);
        lastPhase = phase;
      }

      final date = addMonthsSameCalendarDay(startDate, monthOffset);
      for (final i in active) {
        final pay = balances[i] < share + 0.009 ? balances[i] : share;
        if (pay < 0.009) continue;

        calendar.add(
          _ScheduledClientPayment(
            date: date,
            practiceLabel: numberedDebts[i].label,
            amount: pay,
            practiceInstallmentIndex: ++installmentIndices[i],
          ),
        );
        paymentAmounts[i].add(pay);
        paymentDates[i].add(date);
        balances[i] = (balances[i] - pay).clamp(0.0, double.infinity);

        switch (active.length) {
          case 1:
            soloMonthOffsets[i].add(monthOffset);
            soloDates[i].add(date);
            soloAmounts[i].add(pay);
          case 2:
            bimestralMonthOffsets[i].add(monthOffset);
            biDates[i].add(date);
            biAmounts[i].add(pay);
          default:
            trimestralMonthOffsets[i].add(monthOffset);
            triDates[i].add(date);
            triAmounts[i].add(pay);
        }
      }
      monthOffset++;
    }

    int calendarMonthsSpan(List<int> offsets) {
      if (offsets.isEmpty) return 0;
      final sorted = [...offsets]..sort();
      return sorted.last - sorted.first + 1;
    }

    final practices = <_PracticePdrSchedule>[];
    for (var i = 0; i < n; i++) {
      final amounts = paymentAmounts[i];
      final dates = paymentDates[i];
      final net = numberedDebts[i].netAmount;
      final plan = _RepaymentInstallmentPlan.fromRecordedPayments(
        payments: amounts,
        netAmount: net,
      );
      if (plan == null) return null;

      practices.add(
        _PracticePdrSchedule(
          planNumber: i + 1,
          label: numberedDebts[i].label,
          netAmount: net,
          accontoAmount: numberedDebts[i].accontoAmount,
          plan: plan,
          band: bandFor(net),
          startDate: dates.isEmpty ? startDate : dates.first,
          endDate: dates.isEmpty ? startDate : dates.last,
          trimestralCalendarMonths: calendarMonthsSpan(trimestralMonthOffsets[i]),
          trimestralPaymentCount: trimestralMonthOffsets[i].length,
          bimestralCalendarMonths: calendarMonthsSpan(bimestralMonthOffsets[i]),
          bimestralPaymentCount: bimestralMonthOffsets[i].length,
          soloCalendarMonths: calendarMonthsSpan(soloMonthOffsets[i]),
          soloPaymentCount: soloMonthOffsets[i].length,
          paymentAmounts: amounts,
          dilazionePhases: _buildDilazionePhasesFromSegments(
            triDates: triDates[i],
            triAmounts: triAmounts[i],
            biDates: biDates[i],
            biAmounts: biAmounts[i],
            soloDates: soloDates[i],
            soloAmounts: soloAmounts[i],
          ),
        ),
      );
    }

    practices.sort(_comparePracticeScheduleByNet);

    return _MultiPracticePlanResult(
      monthlyClientPayment: monthlyPayment,
      practices: practices,
      calendar: calendar,
      overallEndDate: calendar.isEmpty ? startDate : calendar.last.date,
      phaseDescriptions: phaseDescriptions,
      monthlyParallel: true,
    );
  }
}

/// Ordine piani multi-pratica: importo netto crescente (poi etichetta).
int _comparePracticeNetAmount(_PracticeDebt a, _PracticeDebt b) {
  final byAmount = a.netAmount.compareTo(b.netAmount);
  if (byAmount != 0) return byAmount;
  return a.label.compareTo(b.label);
}

int _comparePracticeScheduleByNet(_PracticePdrSchedule a, _PracticePdrSchedule b) {
  final byAmount = a.netAmount.compareTo(b.netAmount);
  if (byAmount != 0) return byAmount;
  return a.planNumber.compareTo(b.planNumber);
}

enum _PlanSizingMode { automatic, manual }

enum _ManualSizingTarget {
  byInstallmentAmount,
  byInstallmentCount,
}

class _ManualSizingValidation {
  final bool isValid;
  final String? message;
  final bool showError;

  const _ManualSizingValidation({
    required this.isValid,
    this.message,
    this.showError = false,
  });

  static const ok = _ManualSizingValidation(isValid: true);
}

class _CreditorOption {
  final String id;
  final String name;
  final int maxAgePdr;
  final double minInstallmentAmount;
  final List<_PdrBand> pdrBands;
  final bool bollettiniPostali;
  final bool effettiCambiari;

  const _CreditorOption({
    required this.id,
    required this.name,
    required this.maxAgePdr,
    required this.minInstallmentAmount,
    required this.pdrBands,
    required this.bollettiniPostali,
    required this.effettiCambiari,
  });

  List<String> get availablePaymentMethods {
    final methods = <String>[];
    if (bollettiniPostali) methods.add('Bollettino');
    if (effettiCambiari) methods.add('Cambiali');
    return methods;
  }

  int? get minDebtAmount =>
      pdrBands.isEmpty ? null : pdrBands.first.from;

  int? get maxDebtAmount => pdrBands.isEmpty ? null : pdrBands.last.to;

  _PdrBand? bandForAmount(double amount) {
    final value = amount.round();
    for (final band in pdrBands) {
      if (value >= band.from && value <= band.to) return band;
    }
    return null;
  }
}

class _StandardRepaymentPlanPageState extends State<StandardRepaymentPlanPage> {
  static const _primaryBlue = Color(0xFF0A66C2);

  /// Spese acquisizione cambiali: 12 per mille sull'importo dilazionato.
  static const _cambialiPermille = 12.0;

  String? _creditorId;
  _CreditorOption? _creditor;
  List<_CreditorOption>? _cachedCreditorOptions;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _creditorsSub;
  List<_PracticeDebt> _previewOrderedDebts = const [];

  final _importo1Ctrl = TextEditingController();
  final _importo2Ctrl = TextEditingController();
  final _importo3Ctrl = TextEditingController();
  final _accontoCtrl = TextEditingController(text: '0,00 €');
  final _birthYearCtrl = TextEditingController();
  final _desiredInstallmentCtrl = TextEditingController();
  final _desiredInstallmentCountCtrl = TextEditingController();
  final _rataMensileCondivisaCtrl = TextEditingController();
  final _modPhase1MonthsCtrl = TextEditingController();
  final _modPhase1AmountCtrl = TextEditingController();
  final _modPhase2MonthsCtrl = TextEditingController();
  final _modPhase2AmountCtrl = TextEditingController();
  final _modPhase3MonthsCtrl = TextEditingController();
  final _modPhase3AmountCtrl = TextEditingController();

  DateTime _dataInizio = DateTime.now();
  _PlanSizingMode _planSizingMode = _PlanSizingMode.automatic;
  _ManualSizingTarget _manualTarget = _ManualSizingTarget.byInstallmentAmount;
  bool _manualValidationVisible = false;
  String? _manualSizingError;
  String? _manualSizingHint;
  String _cadenza = 'Mensile';
  int _monthlyPlanCount = 1;
  String _metodo = '';
  _RepaymentSplitMode _modalitaRate = _RepaymentSplitMode.lastAdjustment;

  static const _modalitaRateLabels = {
    _RepaymentSplitMode.lastAdjustment: 'Ultima rata di conguaglio',
    _RepaymentSplitMode.allEqual: 'Tutte le dilazioni uguali',
  };

  static const _maxModulatedPhases = 3;

  int _modulatedVisiblePhaseCount = 1;

  bool _calcolato = false;
  double _netto = 0;
  int _numeroRate = 0;
  DateTime? _dataFine;
  bool _warningEta = false;
  bool _warningPdrAmount = false;
  bool _cappedToAvailableMonths = false;
  bool _showMultiPracticeAmountErrors = false;
  Map<String, String>? _formSnapshotAtCalcolo;
  bool _isResettingForm = false;
  _PdrBand? _matchedPdrBand;
  _RepaymentInstallmentPlan? _installmentPlan;
  _ModulatedRepaymentPlanResult? _modulatedPlan;
  _MultiPracticePlanResult? _multiPracticePlan;
  bool _modulatedValidationVisible = false;
  String? _modulatedSizingError;
  bool _showPdrFeedback = false;
  bool _showBirthYearInfo = false;
  bool _exportingCommissions = false;
  final List<String> _sessionCommissionDocIds = [];

  final _mobileScrollController = ScrollController();
  final _summaryKey = GlobalKey();
  final FocusNode _accontoFocusNode = FocusNode();
  late final Listenable _formAmountFieldsListenable;

  @override
  void initState() {
    super.initState();
    _accontoFocusNode.addListener(_onAccontoFocusChange);
    _formAmountFieldsListenable = Listenable.merge([
      _importo1Ctrl,
      _importo2Ctrl,
      _importo3Ctrl,
      _accontoCtrl,
      _rataMensileCondivisaCtrl,
      _modPhase1MonthsCtrl,
      _modPhase1AmountCtrl,
      _modPhase2MonthsCtrl,
      _modPhase2AmountCtrl,
      _modPhase3MonthsCtrl,
      _modPhase3AmountCtrl,
    ]);
    _creditorsSub =
        FirestoreUserScope.creditorsOrdered().snapshots().listen(
      _applyCreditorsSnapshot,
    );
  }

  @override
  void dispose() {
    _creditorsSub?.cancel();
    _accontoFocusNode.removeListener(_onAccontoFocusChange);
    _accontoFocusNode.dispose();
    _mobileScrollController.dispose();
    _importo1Ctrl.dispose();
    _importo2Ctrl.dispose();
    _importo3Ctrl.dispose();
    _accontoCtrl.dispose();
    _birthYearCtrl.dispose();
    _desiredInstallmentCtrl.dispose();
    _desiredInstallmentCountCtrl.dispose();
    _rataMensileCondivisaCtrl.dispose();
    _modPhase1MonthsCtrl.dispose();
    _modPhase1AmountCtrl.dispose();
    _modPhase2MonthsCtrl.dispose();
    _modPhase2AmountCtrl.dispose();
    _modPhase3MonthsCtrl.dispose();
    _modPhase3AmountCtrl.dispose();
    super.dispose();
  }

  void _resetCalcolo() {
    if (!_calcolato) return;
    setState(() {
      _calcolato = false;
      _formSnapshotAtCalcolo = null;
      _warningEta = false;
      _warningPdrAmount = false;
      _cappedToAvailableMonths = false;
      _showMultiPracticeAmountErrors = false;
      _matchedPdrBand = null;
      _installmentPlan = null;
      _modulatedPlan = null;
      _multiPracticePlan = null;
    });
  }

  Map<String, String> _currentFormSnapshot() {
    return {
      'cadenza': _cadenza,
      'monthlyPlans': '$_monthlyPlanCount',
      'creditorId': _creditorId ?? '',
      'metodo': _metodo,
      'modalita': _modalitaRate.name,
      'planSizing': _planSizingMode.name,
      'manualTarget': _manualTarget.name,
      'i1': _importo1Ctrl.text.trim(),
      'i2': _importo2Ctrl.text.trim(),
      'i3': _importo3Ctrl.text.trim(),
      'acconto': _accontoCtrl.text.trim(),
      'rata': _rataMensileCondivisaCtrl.text.trim(),
      'birth': _birthYearCtrl.text.trim(),
      'start': _formatDate(_dataInizio),
      'desiredRata': _desiredInstallmentCtrl.text.trim(),
      'desiredCount': _desiredInstallmentCountCtrl.text.trim(),
      'mod1m': _modPhase1MonthsCtrl.text.trim(),
      'mod1a': _modPhase1AmountCtrl.text.trim(),
      'mod2m': _modPhase2MonthsCtrl.text.trim(),
      'mod2a': _modPhase2AmountCtrl.text.trim(),
      'mod3m': _modPhase3MonthsCtrl.text.trim(),
      'mod3a': _modPhase3AmountCtrl.text.trim(),
    };
  }

  void _captureFormSnapshot() {
    _formSnapshotAtCalcolo = _currentFormSnapshot();
  }

  bool _hasFormChangedSinceCalcolo() {
    if (!_calcolato || _formSnapshotAtCalcolo == null) return false;
    final current = _currentFormSnapshot();
    if (current.length != _formSnapshotAtCalcolo!.length) return true;
    for (final entry in current.entries) {
      if (_formSnapshotAtCalcolo![entry.key] != entry.value) return true;
    }
    return false;
  }

  void _resetCalcoloIfNeeded() {
    if (!_hasFormChangedSinceCalcolo()) return;
    _resetCalcolo();
  }

  void _applyCreditorsSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    if (!mounted) return;
    final options = _optionsFromSnapshot(snap);

    if (_creditorId != null) {
      _CreditorOption? match;
      for (final option in options) {
        if (option.id == _creditorId) {
          match = option;
          break;
        }
      }
      if (match == null) {
        setState(() {
          _cachedCreditorOptions = options;
          _creditorId = null;
          _creditor = null;
          _calcolato = false;
        });
        return;
      }
      if (_creditor?.id == match.id) {
        _creditor = match;
      }
    }

    if (_cachedCreditorOptions == null) {
      setState(() => _cachedCreditorOptions = options);
      return;
    }

    if (!_creditorOptionsListEquals(_cachedCreditorOptions!, options)) {
      setState(() => _cachedCreditorOptions = options);
    } else {
      _cachedCreditorOptions = options;
    }
  }

  bool _creditorOptionsListEquals(
    List<_CreditorOption> a,
    List<_CreditorOption> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].name != b[i].name) return false;
      if (a[i].pdrBands.length != b[i].pdrBands.length) return false;
    }
    return true;
  }

  void _syncMultiPracticePreview() {
    if (!_usesMultiPracticeForm || !_showPdrFeedback) {
      _previewOrderedDebts = const [];
      return;
    }
    _previewOrderedDebts = _practiceDebtsForCadenza();
  }

  bool get _isRotationMultiPractice =>
      _cadenza == 'Bimestrale' || _cadenza == 'Trimestrale';

  bool get _isMultiPracticeCadenza => _isRotationMultiPractice;

  bool get _isMonthlyParallelMulti =>
      _cadenza == 'Mensile' && _monthlyPlanCount > 1;

  bool get _usesMultiPracticeForm =>
      _isRotationMultiPractice || _isMonthlyParallelMulti;

  bool get _isModulatedCadenza => _cadenza == 'Modulato';

  bool get _usesMonthlyBirthYearLogic =>
      _cadenza == 'Mensile' || _isModulatedCadenza;

  void _formatDebtControllers() {
    for (final controller in [
      _importo1Ctrl,
      _importo2Ctrl,
      _importo3Ctrl,
      _accontoCtrl,
      _rataMensileCondivisaCtrl,
      _modPhase1AmountCtrl,
      _modPhase2AmountCtrl,
      _modPhase3AmountCtrl,
    ]) {
      if (controller.text.trim().isNotEmpty) {
        EuroFormat.applyToController(controller);
      }
    }
  }

  void _onAccontoFocusChange() {
    if (_accontoFocusNode.hasFocus) {
      _accontoCtrl.clear();
      return;
    }
    _commitAcconto();
  }

  void _commitAcconto() {
    if (_isResettingForm) return;
    if (_accontoCtrl.text.trim().isEmpty) {
      _accontoCtrl.text = '0,00 €';
    } else {
      EuroFormat.applyToController(_accontoCtrl);
      if (EuroFormat.parse(_accontoCtrl.text) == null) {
        _accontoCtrl.text = '0,00 €';
      }
    }
    _resetCalcoloIfNeeded();
    setState(() {
      _showPdrFeedback = true;
      if (_parseBirthYear() != null) _showBirthYearInfo = true;
      _syncMultiPracticePreview();
    });
  }

  void _commitBirthYear() {
    if (_isResettingForm) return;
    _resetCalcoloIfNeeded();
    setState(() => _showBirthYearInfo = true);
    _refreshModulatedValidation();
  }

  TextEditingController _practiceGrossController(int index) {
    return switch (index) {
      0 => _importo1Ctrl,
      1 => _importo2Ctrl,
      _ => _importo3Ctrl,
    };
  }

  bool _isPracticeGrossEmpty(int index) {
    final raw = _practiceGrossController(index).text.trim();
    if (raw.isEmpty) return true;
    final value = EuroFormat.parse(raw);
    return value == null || value <= 0;
  }

  List<int> get _emptyPracticeFieldIndexes {
    if (!_usesMultiPracticeForm) return const [];
    return [
      for (var i = 0; i < _multiPracticeFieldCount(); i++)
        if (_isPracticeGrossEmpty(i)) i,
    ];
  }

  String? _practiceFieldError(int index) {
    if (!_showMultiPracticeAmountErrors) return null;
    if (!_emptyPracticeFieldIndexes.contains(index)) return null;
    return requiredFieldError(
      true,
      message: 'Inserisci l\'importo da dilazionare.',
    );
  }

  String? _singlePracticeAmountError() {
    if (!_showPdrFeedback || _usesMultiPracticeForm) return null;
    return requiredFieldError(_isPracticeGrossEmpty(0));
  }

  String? _creditorFieldError() {
    if (!_showPdrFeedback) return null;
    return requiredFieldError(_creditorId == null);
  }

  String? _birthYearFieldError() {
    if (!_showPdrFeedback || _usesMultiPracticeForm) return null;
    return requiredFieldError(_parseBirthYear() == null);
  }

  String? _modulatedMonthsError(int phaseIndex) {
    if (!_modulatedValidationVisible) return null;
    final raw = _allModulatedPhaseControllers[phaseIndex].months.text.trim();
    if (raw.isEmpty) return requiredFieldBorderOnly;
    final months = int.tryParse(raw);
    return requiredFieldError(months == null || months < 1);
  }

  String? _modulatedAmountError(int phaseIndex) {
    if (!_modulatedValidationVisible) return null;
    final raw = _allModulatedPhaseControllers[phaseIndex].amount.text.trim();
    if (raw.isEmpty) return requiredFieldBorderOnly;
    final amount = EuroFormat.parse(raw);
    return requiredFieldError(amount == null || amount <= 0);
  }

  void _revealRequiredFieldErrors() {
    setState(() {
      _showPdrFeedback = true;
      _showBirthYearInfo = true;
      if (_usesMultiPracticeForm) {
        _showMultiPracticeAmountErrors = _emptyPracticeFieldIndexes.isNotEmpty;
      }
      if (_isModulatedCadenza) {
        final check =
            _validateModulatedPlan(showEmptyAsInvalid: true, forceVisible: true);
        _modulatedValidationVisible = !check.isValid;
        _modulatedSizingError = check.isValid ? null : check.message;
      } else if (_planSizingMode == _PlanSizingMode.manual) {
        final check =
            _validateManualSizing(showEmptyAsInvalid: true, forceVisible: true);
        _manualValidationVisible = !check.isValid;
        _manualSizingError = check.isValid ? null : check.message;
        _manualSizingHint = check.isValid ? _manualTargetHint() : null;
      }
    });
  }

  void _refreshMultiPracticeAmountErrors({bool showErrors = true}) {
    if (!_usesMultiPracticeForm) return;
    final hasEmpty = _emptyPracticeFieldIndexes.isNotEmpty;
    if (!showErrors && !_showMultiPracticeAmountErrors) return;
    if (_showMultiPracticeAmountErrors == hasEmpty) return;
    setState(() => _showMultiPracticeAmountErrors = hasEmpty);
  }

  void _syncPaymentMethodForCreditor() {
    final options = _creditor?.availablePaymentMethods ?? [];
    if (options.isEmpty) {
      _metodo = '';
    } else if (!options.contains(_metodo)) {
      _metodo = options.first;
    }
  }

  bool get _canDevelopPlan {
    if (_creditor == null) return false;
    final payMethods = _creditor!.availablePaymentMethods;
    if (payMethods.isEmpty || !payMethods.contains(_metodo)) return false;
    if (_usesMultiPracticeForm) {
      if (_emptyPracticeFieldIndexes.isNotEmpty) return false;
      final rata = EuroFormat.parse(_rataMensileCondivisaCtrl.text);
      if (rata == null || rata <= 0) return false;
      return _practiceDebtsForCadenza().every((p) => p.netAmount > 0);
    }
    if (_isModulatedCadenza) {
      return _validateModulatedPlan(showEmptyAsInvalid: true).isValid;
    }
    return _planSizingMode == _PlanSizingMode.automatic ||
        _validateManualSizing(showEmptyAsInvalid: true).isValid;
  }

  double? get _importoDilazionato {
    if (_multiPracticePlan != null) return _multiPracticePlan!.totalRecovered;
    if (_modulatedPlan != null) return _modulatedPlan!.totalRecovered;
    return _installmentPlan?.totalRecovered;
  }

  List<({TextEditingController months, TextEditingController amount})>
      get _allModulatedPhaseControllers => [
            (months: _modPhase1MonthsCtrl, amount: _modPhase1AmountCtrl),
            (months: _modPhase2MonthsCtrl, amount: _modPhase2AmountCtrl),
            (months: _modPhase3MonthsCtrl, amount: _modPhase3AmountCtrl),
          ];

  List<({TextEditingController months, TextEditingController amount})>
      get _modulatedPhaseControllers => _allModulatedPhaseControllers
          .take(_modulatedVisiblePhaseCount)
          .toList();

  int get _modulatedTabAfterPhases => 6 + _modulatedVisiblePhaseCount * 2;

  void _addModulatedPhase() {
    if (_modulatedVisiblePhaseCount >= _maxModulatedPhases) return;
    setState(() {
      _modulatedVisiblePhaseCount++;
      _resetCalcolo();
    });
    _refreshModulatedValidation();
  }

  void _removeModulatedPhaseAt(int index) {
    if (index <= 0 || index >= _modulatedVisiblePhaseCount) return;
    for (var i = index; i < _modulatedVisiblePhaseCount - 1; i++) {
      final from = _allModulatedPhaseControllers[i + 1];
      final to = _allModulatedPhaseControllers[i];
      to.months.text = from.months.text;
      to.amount.text = from.amount.text;
    }
    final last = _allModulatedPhaseControllers[_modulatedVisiblePhaseCount - 1];
    last.months.clear();
    last.amount.clear();
    setState(() {
      _modulatedVisiblePhaseCount--;
      _resetCalcolo();
    });
    _refreshModulatedValidation();
  }

  List<_ModulatedPhase>? _parsedModulatedPhases({bool requirePhase1 = true}) {
    final phases = <_ModulatedPhase>[];
    for (var i = 0; i < _modulatedVisiblePhaseCount; i++) {
      final pair = _allModulatedPhaseControllers[i];
      final mRaw = pair.months.text.trim();
      final aRaw = pair.amount.text.trim();
      if (mRaw.isEmpty || aRaw.isEmpty) return null;
      final months = int.tryParse(mRaw);
      final amount = EuroFormat.parse(aRaw);
      if (months == null || months < 1 || amount == null || amount <= 0) {
        return null;
      }
      phases.add(_ModulatedPhase(months: months, monthlyAmount: amount));
    }
    if (phases.isEmpty) return null;
    return phases;
  }

  _ManualSizingValidation _validateModulatedPlan({
    bool showEmptyAsInvalid = false,
    bool forceVisible = false,
  }) {
    final showError = forceVisible || _modulatedValidationVisible;

    if (!_isModulatedCadenza) {
      return _ManualSizingValidation.ok;
    }

    final creditor = _creditor;
    final netto = _netDebt();

    if (creditor == null) {
      return _ManualSizingValidation(
        isValid: false,
        message: 'Seleziona un creditore.',
        showError: showError,
      );
    }

    if (netto <= 0) {
      return _ManualSizingValidation(
        isValid: false,
        message: 'Inserisci un importo netto da rateizzare valido.',
        showError: showError,
      );
    }

    final phases = _parsedModulatedPhases(requirePhase1: showEmptyAsInvalid);
    if (phases == null) {
      if (!showEmptyAsInvalid &&
          _modPhase1MonthsCtrl.text.trim().isEmpty &&
          _modPhase1AmountCtrl.text.trim().isEmpty) {
        return _ManualSizingValidation.ok;
      }
      return _ManualSizingValidation(
        isValid: false,
        message: _modulatedVisiblePhaseCount > 1
            ? 'Compila numero di mesi e importo rata per ogni fase.'
            : 'Compila numero di mesi e importo rata mensile.',
        showError: showError,
      );
    }

    final minRata = creditor.minInstallmentAmount > 0
        ? creditor.minInstallmentAmount
        : 0.01;

    for (var i = 0; i < phases.length; i++) {
      final phase = phases[i];
      if (phase.monthlyAmount + 1e-9 < minRata) {
        return _ManualSizingValidation(
          isValid: false,
          message:
              'La rata della fase ${i + 1} (${EuroFormat.format(phase.monthlyAmount)}) '
              'è inferiore al minimo del creditore (${EuroFormat.format(minRata)}).',
          showError: showError,
        );
      }
    }

    final band = creditor.bandForAmount(netto);
    if (band == null || band.installments <= 0) {
      return _ManualSizingValidation(
        isValid: false,
        message: 'L\'importo netto non rientra in una fascia PDR del creditore.',
        showError: showError,
      );
    }

    final maxTotal = _effectiveMaxInstallments(band);
    final modulatedMonths =
        phases.fold<int>(0, (total, p) => total + p.months);
    final modulatedRecovered =
        phases.fold<double>(0, (total, p) => total + p.totalRecovered);

    if (modulatedMonths >= maxTotal) {
      final mesiDisp = _availablePlanMonths();
      final cappedByAge =
          mesiDisp != null && maxTotal < band.installments;
      return _ManualSizingValidation(
        isValid: false,
        message: cappedByAge
            ? 'Le fasi personalizzate durano $modulatedMonths mesi: non restano '
                'dilazioni per il residuo (max $maxTotal con $mesiDisp mesi disponibili, '
                'fascia PDR: ${band.installments}).'
            : 'Le fasi personalizzate durano $modulatedMonths mesi: la fascia PDR '
                'ne consente al massimo $maxTotal; deve restare almeno 1 mese per il residuo.',
        showError: showError,
      );
    }

    final remainingN = maxTotal - modulatedMonths;
    final residual = netto - modulatedRecovered;

    if (residual <= 0.009) {
      return _ManualSizingValidation(
        isValid: false,
        message: modulatedRecovered >= netto
            ? 'Le rate personalizzate coprono già tutto il debito netto: '
                'riduci importi o durata per lasciare un residuo da dilazionare.'
            : 'Il debito residuo da dilazionare deve essere positivo.',
        showError: showError,
      );
    }

    final mesiDisp = _availablePlanMonths();
    if (mesiDisp != null && modulatedMonths + remainingN > mesiDisp) {
      return _ManualSizingValidation(
        isValid: false,
        message:
            'Il piano complessivo dura ${modulatedMonths + remainingN} mesi '
            '($modulatedMonths personalizzati + $remainingN sul residuo), oltre i '
            '$mesiDisp mesi disponibili per età del debitore.',
        showError: showError,
      );
    }

    if (residual / remainingN + 1e-9 < minRata &&
        _modalitaRate != _RepaymentSplitMode.lastAdjustment) {
      return _ManualSizingValidation(
        isValid: false,
        message:
            'Sul residuo di ${EuroFormat.format(residual)} in $remainingN dilazioni '
            'la rata media (${EuroFormat.format(residual / remainingN)}) sarebbe sotto '
            'il minimo (${EuroFormat.format(minRata)}). Accorcia le fasi personalizzate '
            'o usa la modalità conguaglio.',
        showError: showError,
      );
    }

    return _ManualSizingValidation.ok;
  }

  void _commitModulatedValidation() {
    for (final pair in _modulatedPhaseControllers) {
      final digits = pair.months.text.replaceAll(RegExp(r'[^0-9]'), '');
      pair.months.text = digits;
      if (pair.amount.text.trim().isNotEmpty) {
        EuroFormat.applyToController(pair.amount);
      }
    }
    _resetCalcoloIfNeeded();
    _refreshModulatedValidation();
  }

  void _onModulatedFieldChanged() {
    _resetCalcoloIfNeeded();
    _refreshModulatedValidation();
  }

  void _refreshModulatedValidation() {
    if (!_isModulatedCadenza || !mounted) return;

    final hasAnyInput = _modulatedPhaseControllers.any(
      (p) =>
          p.months.text.trim().isNotEmpty || p.amount.text.trim().isNotEmpty,
    );
    if (!hasAnyInput) {
      if (_modulatedValidationVisible || _modulatedSizingError != null) {
        setState(() {
          _modulatedValidationVisible = false;
          _modulatedSizingError = null;
        });
      }
      return;
    }

    final check =
        _validateModulatedPlan(showEmptyAsInvalid: true, forceVisible: true);
    final nextVisible = !check.isValid;
    final nextMessage = nextVisible ? check.message : null;
    if (_modulatedValidationVisible == nextVisible &&
        _modulatedSizingError == nextMessage) {
      return;
    }
    setState(() {
      _modulatedValidationVisible = nextVisible;
      _modulatedSizingError = nextMessage;
    });
  }

  int _multiPracticeFieldCount() {
    return switch (_cadenza) {
      'Trimestrale' => 3,
      'Bimestrale' => 2,
      'Mensile' => _monthlyPlanCount,
      _ => 0,
    };
  }

  List<double> _practiceAccontoAmounts() {
    final count = _multiPracticeFieldCount();
    if (count == 0) return const [];

    final acconto = EuroFormat.parse(_accontoCtrl.text) ?? 0;
    if (acconto <= 0) return List<double>.filled(count, 0);

    final accontoCents = (acconto * 100).round();
    final baseShareCents = accontoCents ~/ count;
    var remainderCents = accontoCents % count;
    final shares = <double>[];
    for (var i = 0; i < count; i++) {
      var shareCents = baseShareCents;
      if (remainderCents > 0) {
        shareCents++;
        remainderCents--;
      }
      shares.add(shareCents / 100);
    }
    return shares;
  }

  /// Debiti netti per pratica, ordinati dal più piccolo al più grande.
  List<_PracticeDebt> _practiceDebtsForCadenza() {
    final count = _multiPracticeFieldCount();
    if (count == 0) return const [];

    final nets = _practiceNetAmounts().take(count).toList();
    final accontos = _practiceAccontoAmounts().take(count).toList();
    final indexed = <({int fieldNumber, double netAmount, double accontoAmount})>[
      for (var i = 0; i < nets.length; i++)
        (
          fieldNumber: i + 1,
          netAmount: nets[i],
          accontoAmount: accontos[i],
        ),
    ];
    indexed.sort((a, b) {
      final byAmount = a.netAmount.compareTo(b.netAmount);
      if (byAmount != 0) return byAmount;
      return a.fieldNumber.compareTo(b.fieldNumber);
    });

    return [
      for (var i = 0; i < indexed.length; i++)
        (
          label: 'Piano di rientro ${i + 1}',
          netAmount: indexed[i].netAmount,
          accontoAmount: indexed[i].accontoAmount,
        ),
    ];
  }

  List<double> _practiceNetAmounts() {
    final gross = <double>[
      EuroFormat.parse(_importo1Ctrl.text) ?? 0,
      EuroFormat.parse(_importo2Ctrl.text) ?? 0,
      EuroFormat.parse(_importo3Ctrl.text) ?? 0,
    ];
    final count = _multiPracticeFieldCount() > 0
        ? _multiPracticeFieldCount()
        : 1;
    final practiceGross = gross.take(count).toList();
    final totalGross =
        practiceGross.fold<double>(0, (total, value) => total + value);
    if (totalGross <= 0) {
      return List<double>.filled(count, 0);
    }

    final acconto = EuroFormat.parse(_accontoCtrl.text) ?? 0;
    if (_usesMultiPracticeForm && count > 0) {
      final accontoCents = (acconto * 100).round();
      final baseShareCents = accontoCents ~/ count;
      var remainderCents = accontoCents % count;
      final nets = <double>[];
      for (var i = 0; i < count; i++) {
        var deductCents = baseShareCents;
        if (remainderCents > 0) {
          deductCents++;
          remainderCents--;
        }
        final netCents = (practiceGross[i] * 100).round() - deductCents;
        nets.add(netCents <= 0 ? 0.0 : netCents / 100);
      }
      return nets;
    }

    final totalNet =
        totalGross - acconto < 0 ? 0.0 : totalGross - acconto;
    return practiceGross.map((g) => g * totalNet / totalGross).toList();
  }

  double _costoAcquisizioneCambiali(double importoDilazionato) {
    final cents =
        (importoDilazionato * _cambialiPermille / 1000 * 100).round();
    return cents / 100;
  }

  bool _canPressSviluppaPiano(List<_CreditorOption> options) =>
      options.isNotEmpty && _canDevelopPlan;

  void _resetForm() {
    _isResettingForm = true;
    FocusManager.instance.primaryFocus?.unfocus();
    _accontoFocusNode.unfocus();

    void applyReset() {
      if (!mounted) return;
      setState(() {
      _cadenza = 'Mensile';
      _monthlyPlanCount = 1;
      _metodo = '';
      _modalitaRate = _RepaymentSplitMode.lastAdjustment;
      _planSizingMode = _PlanSizingMode.automatic;
      _manualTarget = _ManualSizingTarget.byInstallmentAmount;
      _manualValidationVisible = false;
      _manualSizingError = null;
      _manualSizingHint = null;
      _desiredInstallmentCtrl.clear();
      _desiredInstallmentCountCtrl.clear();
      _rataMensileCondivisaCtrl.clear();
      _modPhase1MonthsCtrl.clear();
      _modPhase1AmountCtrl.clear();
      _modPhase2MonthsCtrl.clear();
      _modPhase2AmountCtrl.clear();
      _modPhase3MonthsCtrl.clear();
      _modPhase3AmountCtrl.clear();
      _modulatedVisiblePhaseCount = 1;
      _modulatedValidationVisible = false;
      _modulatedSizingError = null;
      _creditorId = null;
      _creditor = null;
      _dataInizio = DateTime.now();
      _importo1Ctrl.clear();
      _importo2Ctrl.clear();
      _importo3Ctrl.clear();
      _accontoCtrl.text = '0,00 €';
      _birthYearCtrl.clear();
      _calcolato = false;
      _netto = 0;
      _numeroRate = 0;
      _dataFine = null;
      _warningEta = false;
      _warningPdrAmount = false;
      _cappedToAvailableMonths = false;
      _showMultiPracticeAmountErrors = false;
      _formSnapshotAtCalcolo = null;
      _matchedPdrBand = null;
      _installmentPlan = null;
      _modulatedPlan = null;
      _multiPracticePlan = null;
      _showPdrFeedback = false;
      _showBirthYearInfo = false;
      _previewOrderedDebts = const [];
      _sessionCommissionDocIds.clear();
      });
      _isResettingForm = false;
      if (_mobileScrollController.hasClients) {
        _mobileScrollController.jumpTo(0);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => applyReset());
  }

  double _netDebt() {
    if (_usesMultiPracticeForm) {
      return _practiceNetAmounts().fold<double>(0, (total, net) => total + net);
    }
    final acconto = EuroFormat.parse(_accontoCtrl.text) ?? 0;
    final netto = _totaleImporti() - acconto;
    return netto < 0 ? 0 : netto;
  }

  int _cadenzaFactor() {
    switch (_cadenza) {
      case 'Bimestrale':
        return 2;
      case 'Trimestrale':
        return 3;
      default:
        return 1;
    }
  }

  double _totaleImporti() {
    final i1 = EuroFormat.parse(_importo1Ctrl.text) ?? 0;
    final i2 = EuroFormat.parse(_importo2Ctrl.text) ?? 0;
    final i3 = EuroFormat.parse(_importo3Ctrl.text) ?? 0;

    switch (_cadenza) {
      case 'Bimestrale':
        return i1 + i2;
      case 'Trimestrale':
        return i1 + i2 + i3;
      case 'Mensile':
        return switch (_monthlyPlanCount) {
          3 => i1 + i2 + i3,
          2 => i1 + i2,
          _ => i1,
        };
      default:
        return i1;
    }
  }

  int? _parseBirthYear() {
    final raw = _birthYearCtrl.text.trim();
    if (raw.length != 4) return null;
    return int.tryParse(raw);
  }

  /// Età in anni (anno in corso − anno di nascita).
  int? _debtorAgeYears() {
    final birthYear = _parseBirthYear();
    if (birthYear == null) return null;
    return DateTime.now().year - birthYear;
  }

  /// Mesi residui fino all'età massima PDR del creditore.
  int? _availablePlanMonths() {
    final age = _debtorAgeYears();
    if (age == null || _creditor == null) return null;
    if (age < 0) return 0;
    final months = (_creditor!.maxAgePdr - age) * 12;
    return months < 0 ? 0 : months;
  }

  /// Dilazioni massime ammesse dai mesi residui (mensile e modulato).
  int? _maxInstallmentsFromAvailableMonths() {
    if (!_usesMonthlyBirthYearLogic) return null;
    final mesi = _availablePlanMonths();
    if (mesi == null) return null;
    final factor = _cadenzaFactor();
    if (factor <= 0) return null;
    return mesi ~/ factor;
  }

  int _effectiveMaxInstallments(_PdrBand band) {
    if (!_usesMonthlyBirthYearLogic) return band.installments;
    final fromAge = _maxInstallmentsFromAvailableMonths();
    if (fromAge == null) return band.installments;
    return fromAge < band.installments ? fromAge : band.installments;
  }

  _PdrBand? _pdrBandForCurrentNet() {
    final creditor = _creditor;
    if (creditor == null) return null;
    final netto = _netDebt();
    if (netto <= 0) return null;
    return creditor.bandForAmount(netto);
  }

  /// Mesi residui inferiori al massimo dilazioni della fascia PDR (mensile/modulato).
  bool get _monthsBelowPdrSheetInstallments {
    if (!_usesMonthlyBirthYearLogic || !_showBirthYearInfo) return false;
    final months = _availablePlanMonths();
    final band = _pdrBandForCurrentNet();
    if (months == null || band == null) return false;
    return months < band.installments;
  }

  int? _resolvedManualInstallmentCount() {
    if (_planSizingMode != _PlanSizingMode.manual) return null;

    final netto = _netDebt();
    if (netto <= 0) return null;

    switch (_manualTarget) {
      case _ManualSizingTarget.byInstallmentAmount:
        final desired = EuroFormat.parse(_desiredInstallmentCtrl.text);
        if (desired == null || desired <= 0) return null;
        if (_modalitaRate == _RepaymentSplitMode.lastAdjustment) {
          final creditor = _creditor;
          if (creditor == null) return null;
          return _RepaymentInstallmentPlan.installmentCountForDesiredLastAdjustment(
            netAmount: netto,
            desiredInstallment: desired,
            minInstallment: creditor.minInstallmentAmount,
          );
        }
        return _RepaymentInstallmentPlan.installmentCountForDesiredAmount(
          netAmount: netto,
          desiredInstallment: desired,
        );
      case _ManualSizingTarget.byInstallmentCount:
        return int.tryParse(_desiredInstallmentCountCtrl.text.trim());
    }
  }

  _ManualSizingValidation _validateManualSizing({
    bool showEmptyAsInvalid = false,
    bool forceVisible = false,
    double? netAmountOverride,
    int? maxInstallmentsOverride,
  }) {
    if (_planSizingMode != _PlanSizingMode.manual) {
      return _ManualSizingValidation.ok;
    }

    final creditor = _creditor;
    final netto = netAmountOverride ?? _netDebt();
    final showError = forceVisible || _manualValidationVisible;

    if (creditor == null) {
      return _ManualSizingValidation(
        isValid: false,
        message: 'Seleziona un creditore.',
        showError: showError,
      );
    }

    if (netto <= 0) {
      return _ManualSizingValidation(
        isValid: false,
        message: 'Inserisci un importo netto da rateizzare valido.',
        showError: showError,
      );
    }

    final band = creditor.bandForAmount(netto);
    if (band == null || band.installments <= 0) {
      return _ManualSizingValidation(
        isValid: false,
        message: 'L\'importo netto non rientra in una fascia PDR del creditore.',
        showError: showError,
      );
    }

    final maxN = maxInstallmentsOverride ?? _effectiveMaxInstallments(band);
    final minRata = creditor.minInstallmentAmount > 0
        ? creditor.minInstallmentAmount
        : 0.01;
    final mesiDisp = _availablePlanMonths();

    int mesiPiano(int n) => n * _cadenzaFactor();

    final cappedByAge = maxInstallmentsOverride == null &&
        _usesMonthlyBirthYearLogic &&
        mesiDisp != null &&
        maxN < band.installments;

    switch (_manualTarget) {
      case _ManualSizingTarget.byInstallmentAmount:
        final desired = EuroFormat.parse(_desiredInstallmentCtrl.text);
        if (desired == null || desired <= 0) {
          if (!showEmptyAsInvalid &&
              _desiredInstallmentCtrl.text.trim().isEmpty) {
            return _ManualSizingValidation.ok;
          }
          return _ManualSizingValidation(
            isValid: false,
            message: 'Inserisci un importo rata desiderato valido.',
            showError: showError,
          );
        }

        if (desired + 1e-9 < minRata) {
          return _ManualSizingValidation(
            isValid: false,
            message:
                'L\'importo ${EuroFormat.format(desired)} è inferiore alla rata '
                'minima del creditore (${EuroFormat.format(minRata)}).',
            showError: showError,
          );
        }

        if (desired - netto > 0.009) {
          return _ManualSizingValidation(
            isValid: false,
            message:
                'L\'importo ${EuroFormat.format(desired)} supera il debito netto '
                '(${EuroFormat.format(netto)}): servirebbe una sola dilazione.',
            showError: showError,
          );
        }

        final n = _modalitaRate == _RepaymentSplitMode.lastAdjustment
            ? _RepaymentInstallmentPlan.installmentCountForDesiredLastAdjustment(
                netAmount: netto,
                desiredInstallment: desired,
                minInstallment: minRata,
              )
            : _RepaymentInstallmentPlan.installmentCountForDesiredAmount(
                netAmount: netto,
                desiredInstallment: desired,
              );
        if (n == null) {
          return _ManualSizingValidation(
            isValid: false,
            message: _modalitaRate == _RepaymentSplitMode.lastAdjustment
                ? 'Con rata ${EuroFormat.format(desired)} non è possibile '
                    'chiudere il debito con un\'ultima rata di conguaglio '
                    'almeno pari al minimo (${EuroFormat.format(minRata)}).'
                : 'Impossibile calcolare il numero di dilazioni.',
            showError: showError,
          );
        }

        if (n > maxN) {
          return _ManualSizingValidation(
            isValid: false,
            message: cappedByAge
                ? 'Con rata ${EuroFormat.format(desired)} servirebbero $n dilazioni; '
                    'con $mesiDisp mesi disponibili ne sono consentite al massimo $maxN '
                    '${maxInstallmentsOverride != null ? 'per il residuo' : ''} '
                    '(fascia PDR: ${band.installments}).'
                : 'Con rata ${EuroFormat.format(desired)} servirebbero $n dilazioni; '
                    '${maxInstallmentsOverride != null ? 'sul residuo ' : ''}'
                    'ne sono consentite al massimo $maxN.',
            showError: showError,
          );
        }

        if (_modalitaRate == _RepaymentSplitMode.lastAdjustment && n > 1) {
          final totalCents = (netto * 100).round();
          final equalCents = (desired * 100).round();
          final lastCents = totalCents - equalCents * (n - 1);
          if (lastCents <= 0) {
            return _ManualSizingValidation(
              isValid: false,
              message:
                  'Con ${EuroFormat.format(desired)} per $n dilazioni non resta '
                  'un importo valido per l\'ultima rata di conguaglio.',
              showError: showError,
            );
          }
          final lastAmount = lastCents / 100;
          if (lastAmount + 1e-9 < minRata) {
            return _ManualSizingValidation(
              isValid: false,
              message:
                  'L\'ultima rata di conguaglio sarebbe '
                  '${EuroFormat.format(lastAmount)}, sotto il minimo '
                  '(${EuroFormat.format(minRata)}).',
              showError: showError,
            );
          }
        } else if (netto / n + 1e-9 < minRata) {
          return _ManualSizingValidation(
            isValid: false,
            message:
                'Con $n dilazioni la rata media '
                '(${EuroFormat.format(netto / n)}) sarebbe sotto il minimo '
                '(${EuroFormat.format(minRata)}).',
            showError: showError,
          );
        }

        if (mesiDisp != null && mesiPiano(n) > mesiDisp) {
          return _ManualSizingValidation(
            isValid: false,
            message:
                'Con $n dilazioni il piano dura ${mesiPiano(n)} mesi, oltre i '
                '$mesiDisp mesi disponibili per età del debitore.',
            showError: showError,
          );
        }

        return _ManualSizingValidation.ok;

      case _ManualSizingTarget.byInstallmentCount:
        final raw = _desiredInstallmentCountCtrl.text.trim();
        final n = int.tryParse(raw);
        if (n == null || n < 1) {
          if (!showEmptyAsInvalid && raw.isEmpty) {
            return _ManualSizingValidation.ok;
          }
          return _ManualSizingValidation(
            isValid: false,
            message: 'Inserisci un numero di dilazioni valido (≥ 1).',
            showError: showError,
          );
        }

        if (n > maxN) {
          return _ManualSizingValidation(
            isValid: false,
            message: cappedByAge
                ? '$n dilazioni superano il massimo consentito ($maxN) '
                    '${maxInstallmentsOverride != null ? 'sul residuo ' : ''}'
                    'in base ai $mesiDisp mesi disponibili '
                    '(fascia PDR: ${band.installments}).'
                : '$n dilazioni superano il massimo '
                    '${maxInstallmentsOverride != null ? 'sul residuo ' : ''}'
                    'consentito dalla fascia ($maxN).',
            showError: showError,
          );
        }

        if (_modalitaRate == _RepaymentSplitMode.lastAdjustment) {
          if (n == 1) {
            if (netto + 1e-9 < minRata) {
              return _ManualSizingValidation(
                isValid: false,
                message:
                    'L\'unica dilazione ${maxInstallmentsOverride != null ? 'sul residuo ' : ''}'
                    '(${EuroFormat.format(netto)}) è sotto il '
                    'minimo (${EuroFormat.format(minRata)}).',
                showError: showError,
              );
            }
          } else {
            final totalCents = (netto * 100).round();
            final equalCents = (netto / n).floor() * 100;
            final lastCents = totalCents - equalCents * (n - 1);
            if (lastCents <= 0) {
              return _ManualSizingValidation(
                isValid: false,
                message:
                    'Con $n dilazioni non è possibile ripartire il debito in '
                    'conguaglio.',
                showError: showError,
              );
            }
            final equalAmount = equalCents / 100;
            final lastAmount = lastCents / 100;
            if (equalAmount + 1e-9 < minRata) {
              return _ManualSizingValidation(
                isValid: false,
                message:
                    'Le prime ${n - 1} dilazioni sarebbero '
                    '${EuroFormat.format(equalAmount)}, sotto il minimo '
                    '(${EuroFormat.format(minRata)}).',
                showError: showError,
              );
            }
            if (lastAmount + 1e-9 < minRata) {
              return _ManualSizingValidation(
                isValid: false,
                message:
                    'L\'ultima rata di conguaglio sarebbe '
                    '${EuroFormat.format(lastAmount)}, sotto il minimo '
                    '(${EuroFormat.format(minRata)}).',
                showError: showError,
              );
            }
          }
        } else if (netto / n + 1e-9 < minRata) {
          return _ManualSizingValidation(
            isValid: false,
            message:
                'Con $n dilazioni la rata media '
                '(${EuroFormat.format(netto / n)}) è inferiore al minimo '
                '(${EuroFormat.format(minRata)}).',
            showError: showError,
          );
        }

        if (mesiDisp != null && mesiPiano(n) > mesiDisp) {
          return _ManualSizingValidation(
            isValid: false,
            message:
                '$n dilazioni corrispondono a ${mesiPiano(n)} mesi di piano, '
                'oltre i $mesiDisp mesi disponibili.',
            showError: showError,
          );
        }

        return _ManualSizingValidation.ok;
    }
  }

  void _commitManualValidation() {
    if (_manualTarget == _ManualSizingTarget.byInstallmentAmount) {
      EuroFormat.applyToController(_desiredInstallmentCtrl);
    } else {
      final digits =
          _desiredInstallmentCountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      _desiredInstallmentCountCtrl.text = digits;
    }

    _resetCalcolo();
    final check =
        _validateManualSizing(showEmptyAsInvalid: true, forceVisible: true);
    setState(() {
      _manualValidationVisible = true;
      _manualSizingError = check.isValid ? null : check.message;
      _manualSizingHint = check.isValid ? _manualTargetHint() : null;
    });
  }

  void _prepareFieldsBeforeDevelop() {
    FocusManager.instance.primaryFocus?.unfocus();
    _formatDebtControllers();
  }

  Future<void> _calcola() async {
    if (_creditor == null) return;

    _prepareFieldsBeforeDevelop();

    setState(() {
      _showPdrFeedback = true;
      _showBirthYearInfo = true;
    });

    // Lascia disegnare lo UI prima del calcolo (evita freeze percepito al tap).
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    if (_usesMultiPracticeForm && _emptyPracticeFieldIndexes.isNotEmpty) {
      setState(() => _showMultiPracticeAmountErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Compila tutti gli importi da dilazionare prima di sviluppare il piano.',
          ),
        ),
      );
      return;
    }
    _syncMultiPracticePreview();

    final age = _debtorAgeYears();
    final eta = (age != null && age > 0) ? age : 0;

    if (!_usesMultiPracticeForm && _parseBirthYear() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci l\'anno di nascita del debitore (4 cifre).'),
        ),
      );
      return;
    }

    _netto = _netDebt();
    if (_netto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un importo da rateizzare valido.'),
        ),
      );
      return;
    }

    if (_usesMultiPracticeForm) {
      _calcolaMultiPractice(eta);
      return;
    }

    if (_isModulatedCadenza) {
      _calcolaModulated(eta);
      return;
    }

    _matchedPdrBand = _creditor!.bandForAmount(_netto);
    if (_matchedPdrBand == null || _matchedPdrBand!.installments <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Importo netto non rientra in una fascia PDR valida del creditore.',
          ),
        ),
      );
      return;
    }

    if (_planSizingMode == _PlanSizingMode.manual) {
      final manualCheck =
          _validateManualSizing(showEmptyAsInvalid: true, forceVisible: true);
      if (!manualCheck.isValid) {
        setState(() {
          _manualValidationVisible = true;
          _manualSizingError = manualCheck.message;
          _manualSizingHint = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              manualCheck.message ??
                  'Correggi i parametri manuali del piano.',
            ),
          ),
        );
        return;
      }
    }

    int? fixedCount;
    double? chosenRata;
    if (_planSizingMode == _PlanSizingMode.manual) {
      fixedCount = _resolvedManualInstallmentCount();
      if (fixedCount == null) return;
      if (_manualTarget == _ManualSizingTarget.byInstallmentAmount &&
          _modalitaRate == _RepaymentSplitMode.lastAdjustment) {
        chosenRata = EuroFormat.parse(_desiredInstallmentCtrl.text);
        if (chosenRata == null || chosenRata <= 0) return;
      }
    }

    final effectiveMax = _effectiveMaxInstallments(_matchedPdrBand!);
    _cappedToAvailableMonths =
        effectiveMax < _matchedPdrBand!.installments;

    if (effectiveMax < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Non ci sono mesi disponibili sufficienti per sviluppare il piano.',
          ),
        ),
      );
      return;
    }

    final plan = _RepaymentInstallmentPlan.build(
      netAmount: _netto,
      maxInstallments: effectiveMax,
      minInstallment: _creditor!.minInstallmentAmount,
      mode: _modalitaRate,
      fixedInstallmentCount: fixedCount,
      chosenInstallmentAmount: chosenRata,
    );
    if (plan == null) {
      final minRata = _creditor!.minInstallmentAmount;
      final requiredN = fixedCount ??
          (_modalitaRate == _RepaymentSplitMode.lastAdjustment
              ? _RepaymentInstallmentPlan.installmentCountForLastAdjustment(
                  netAmount: _netto,
                  minInstallment: minRata,
                )
              : _RepaymentInstallmentPlan.installmentCountForMinAmount(
                  netAmount: _netto,
                  minInstallment: minRata,
                ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fixedCount != null
                ? 'Con $fixedCount dilazioni non si rispetta l\'importo '
                    'minimo rata (${EuroFormat.format(minRata)}).'
                : requiredN != null && requiredN > effectiveMax
                    ? 'Per rispettare il minimo rata '
                        '(${EuroFormat.format(minRata)}) servono almeno '
                        '$requiredN dilazioni; ne sono consentite al massimo '
                        '$effectiveMax.'
                    : 'Non è possibile rispettare il minimo rata '
                        '(${EuroFormat.format(minRata)}).',
          ),
        ),
      );
      return;
    }

    _installmentPlan = plan;
    _modulatedPlan = null;
    _multiPracticePlan = null;
    final fattore = _cadenzaFactor();
    _numeroRate = plan.installmentCount;
    final mesiPiano = _numeroRate * fattore;

    _dataFine = addMonthsSameCalendarDay(
      _dataInizio,
      mesiPiano > 0 ? mesiPiano - 1 : 0,
    );

    final mesiDisponibili = _availablePlanMonths() ?? 0;
    _warningEta = mesiPiano > mesiDisponibili && eta > 0;

    final minDebt = _creditor!.minDebtAmount;
    final maxDebt = _creditor!.maxDebtAmount;
    _warningPdrAmount = minDebt != null &&
        maxDebt != null &&
        (_netto.round() < minDebt || _netto.round() > maxDebt);

    _captureFormSnapshot();
    setState(() => _calcolato = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSummary());
  }

  void _calcolaModulated(int eta) {
    final modCheck =
        _validateModulatedPlan(showEmptyAsInvalid: true, forceVisible: true);
    if (!modCheck.isValid) {
      setState(() {
        _modulatedValidationVisible = true;
        _modulatedSizingError = modCheck.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            modCheck.message ?? 'Correggi le fasi del piano modulato.',
          ),
        ),
      );
      return;
    }

    final phases = _parsedModulatedPhases(requirePhase1: true)!;
    final modulatedMonths =
        phases.fold<int>(0, (total, p) => total + p.months);
    final modulatedRecovered =
        phases.fold<double>(0, (total, p) => total + p.totalRecovered);
    final residual = _netto - modulatedRecovered;

    _matchedPdrBand = _creditor!.bandForAmount(_netto);
    if (_matchedPdrBand == null) return;

    final effectiveMax = _effectiveMaxInstallments(_matchedPdrBand!);
    final remainingN = effectiveMax - modulatedMonths;
    _cappedToAvailableMonths = effectiveMax < _matchedPdrBand!.installments;

    final finalPlan = _RepaymentInstallmentPlan.build(
      netAmount: residual,
      maxInstallments: remainingN,
      minInstallment: _creditor!.minInstallmentAmount,
      mode: _modalitaRate,
      fixedInstallmentCount: remainingN,
    );

    if (finalPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossibile dilazionare il residuo di ${EuroFormat.format(residual)} '
            'in $remainingN dilazioni '
            '(minimo rata ${EuroFormat.format(_creditor!.minInstallmentAmount)}).',
          ),
        ),
      );
      return;
    }

    _modulatedPlan = _ModulatedRepaymentPlanResult(
      phases: phases,
      netAmountOriginal: _netto,
      modulatedRecovered: modulatedRecovered,
      residualDebt: residual,
      modulatedMonths: modulatedMonths,
      finalInstallmentCount: finalPlan.installmentCount,
      finalPlan: finalPlan,
      planStartDate: _dataInizio,
    );
    _installmentPlan = null;
    _multiPracticePlan = null;
    _numeroRate = modulatedMonths + finalPlan.installmentCount;
    _dataFine = addMonthsSameCalendarDay(
      _dataInizio,
      _modulatedPlan!.totalMonths > 0 ? _modulatedPlan!.totalMonths - 1 : 0,
    );

    final mesiDisponibili = _availablePlanMonths() ?? 0;
    _warningEta =
        _modulatedPlan!.totalMonths > mesiDisponibili && eta > 0;

    final minDebt = _creditor!.minDebtAmount;
    final maxDebt = _creditor!.maxDebtAmount;
    _warningPdrAmount = minDebt != null &&
        maxDebt != null &&
        (_netto.round() < minDebt || _netto.round() > maxDebt);

    _captureFormSnapshot();
    setState(() {
      _calcolato = true;
      _modulatedSizingError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSummary());
  }

  void _calcolaMultiPractice(int eta) {
    final creditor = _creditor!;
    final rata = EuroFormat.parse(_rataMensileCondivisaCtrl.text);
    if (rata == null || rata <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isMonthlyParallelMulti
                ? 'Inserisci l\'importo mensile disponibile.'
                : 'Inserisci l\'importo rata mensile condivisa.',
          ),
        ),
      );
      return;
    }

    if (_emptyPracticeFieldIndexes.isNotEmpty) {
      setState(() => _showMultiPracticeAmountErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Compila tutti gli importi da dilazionare prima di sviluppare il piano.',
          ),
        ),
      );
      return;
    }

    final debts = _practiceDebtsForCadenza();
    if (debts.any((d) => d.netAmount <= 0)) {
      setState(() => _showMultiPracticeAmountErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci tutti gli importi delle pratiche.'),
        ),
      );
      return;
    }

    final outcome = _MultiPracticePlanResult.tryBuild(
      practiceDebts: debts,
      monthlyPayment: rata,
      startDate: _dataInizio,
      minInstallment: creditor.minInstallmentAmount,
      pdrBands: creditor.pdrBands,
      monthlyParallel: _isMonthlyParallelMulti,
    );

    if (outcome.result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.errorMessage ??
                'Impossibile strutturare i piani. Verifica importi e rata minima.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    final multi = outcome.result!;
    _multiPracticePlan = multi;
    _installmentPlan = null;
    _modulatedPlan = null;
    _matchedPdrBand = creditor.bandForAmount(_netto);
    _numeroRate = multi.calendar.length;
    _dataFine = multi.overallEndDate;

    final mesiPiano = _monthsBetween(_dataInizio, multi.overallEndDate);
    final mesiDisponibili = _availablePlanMonths() ?? 0;
    _warningEta =
        !_isMonthlyParallelMulti && mesiPiano > mesiDisponibili && eta > 0;

    final minDebt = creditor.minDebtAmount;
    final maxDebt = creditor.maxDebtAmount;
    _warningPdrAmount = !_isMonthlyParallelMulti &&
        minDebt != null &&
        maxDebt != null &&
        (_netto.round() < minDebt || _netto.round() > maxDebt);

    _captureFormSnapshot();
    setState(() => _calcolato = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSummary());
  }

  int _monthsBetween(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }

  /// Mesi di calendario inclusi tra prima e ultima scadenza della pratica.
  int _monthsSpanInclusive(DateTime from, DateTime to) {
    final span = _monthsBetween(from, to);
    return span < 0 ? 0 : span + 1;
  }

  String _multiPracticePhaseDetail(
    int paymentCount,
    int calendarMonths,
    String label,
  ) {
    if (paymentCount <= 0 || calendarMonths <= 0) return '';
    final rateWord = paymentCount == 1 ? 'rata' : 'rate';
    final monthWord = calendarMonths == 1 ? 'mese' : 'mesi';
    return '$paymentCount $rateWord in $calendarMonths $monthWord $label';
  }

  String _practicePhaseMonthsSuffix(_PracticePdrSchedule practice) {
    final total = _monthsSpanInclusive(practice.startDate, practice.endDate);
    if (!_usesMultiPracticeForm) {
      if (total <= 0) return '';
      final unit = total == 1 ? 'mese' : 'mesi';
      return ' ($total $unit)';
    }

    final tripleLabel = _isMonthlyParallelMulti
        ? 'con quota su 3 piani'
        : 'in rotazione trimestrale';
    final doubleLabel = _isMonthlyParallelMulti
        ? 'con quota su 2 piani'
        : 'in rotazione bimestrale';
    final soloLabel = _isMonthlyParallelMulti
        ? 'a importo mensile intero'
        : 'mensili a chiusura';

    final parts = <String>[
      _multiPracticePhaseDetail(
        practice.trimestralPaymentCount,
        practice.trimestralCalendarMonths,
        tripleLabel,
      ),
      _multiPracticePhaseDetail(
        practice.bimestralPaymentCount,
        practice.bimestralCalendarMonths,
        doubleLabel,
      ),
      _multiPracticePhaseDetail(
        practice.soloPaymentCount,
        practice.soloCalendarMonths,
        soloLabel,
      ),
    ].where((s) => s.isNotEmpty);

    final detail = parts.join(', ');
    if (detail.isEmpty) {
      if (total <= 0) return '';
      final unit = total == 1 ? 'mese' : 'mesi';
      return ' ($total $unit)';
    }

    if (total > 0) {
      final unit = total == 1 ? 'mese' : 'mesi';
      return ' ($total $unit totali: $detail)';
    }
    return ' ($detail)';
  }

  String _practicePaymentCadenceHint(_PracticePdrSchedule practice) {
    if (!_usesMultiPracticeForm) {
      return 'Scadenze: una al mese, giorno ${_dataInizio.day} (come data inizio)';
    }
    if (_isMonthlyParallelMulti) {
      final segments = <String>[
        if (practice.trimestralPaymentCount > 0)
          'quota mensile ÷ 3 piani attivi',
        if (practice.bimestralPaymentCount > 0)
          'quota mensile ÷ 2 piani attivi',
        if (practice.soloPaymentCount > 0) 'intero importo mensile disponibile',
      ];
      return 'Cadenza rate: ${segments.join(' → ')} · '
          'pagamento ogni mese calendario · giorno ${_dataInizio.day} (come data inizio)';
    }
    final segments = <String>[
      if (practice.trimestralPaymentCount > 0)
        'trimestrale mentre restano 3 pratiche',
      if (practice.bimestralPaymentCount > 0)
        'bimestrale mentre restano 2 pratiche',
      if (practice.soloPaymentCount > 0) 'mensile sulla pratica residua',
    ];
    return 'Cadenza rate: ${segments.join(' → ')} · '
        'giorno ${_dataInizio.day} (come data inizio)';
  }

  void _scrollToSummary() {
    final target = _summaryKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  Future<void> _pickDataInizio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInizio,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dataInizio = picked;
        _showPdrFeedback = true;
        if (_parseBirthYear() != null) _showBirthYearInfo = true;
        _resetCalcolo();
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<_PdrBand> _parsePdrBands(dynamic raw) {
    if (raw is! List) return const [];
    final bands = <_PdrBand>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final from = int.tryParse('${item['from']}') ?? 0;
      final to = int.tryParse('${item['to']}') ?? 0;
      final installments = int.tryParse('${item['installments']}') ?? 0;
      if (from <= 0 && to <= 0) continue;
      bands.add(
        _PdrBand(from: from, to: to, installments: installments),
      );
    }
    bands.sort((a, b) => a.from.compareTo(b.from));
    return bands;
  }

  List<_CreditorOption> _optionsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final docs = FirestoreUserScope.sortCreditorsByCreatedAt(snap.docs);
    return docs.map((doc) {
      final data = doc.data();
      final name = (data['name'] ?? 'Senza nome').toString().trim();
      final maxAgeRaw = data['maxAgePdr'] ?? data['maxAge'];
      final maxAgePdr = maxAgeRaw is int
          ? maxAgeRaw
          : int.tryParse(maxAgeRaw?.toString() ?? '') ?? 80;
      final minRaw = data['minInstallmentAmount'];
      final minInstallment = minRaw is num
          ? minRaw.toDouble()
          : double.tryParse(minRaw?.toString() ?? '') ?? 0;
      final methods =
          (data['paymentMethods'] as Map<String, dynamic>?) ?? {};
      return _CreditorOption(
        id: doc.id,
        name: name.isEmpty ? 'Senza nome' : name,
        maxAgePdr: maxAgePdr,
        minInstallmentAmount: minInstallment,
        pdrBands: _parsePdrBands(data['pdrBands']),
        bollettiniPostali: methods['bollettiniPostali'] == true,
        effettiCambiari: methods['effettiCambiari'] == true,
      );
    }).toList();
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: _primaryBlue, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool highlight = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ??
                    (highlight ? _primaryBlue : Colors.black87),
                fontSize: highlight ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Decurtazione = importo netto originario − totale recuperato.
  String _decurtazioneParenthesisText(double originalNet, double totalRecovered) {
    final decurtazione = originalNet - totalRecovered;
    if (decurtazione.abs() < 0.009) return '(0,00 €)';
    return '(- ${EuroFormat.format(decurtazione)})';
  }

  Color _decurtazioneParenthesisColor(double originalNet, double totalRecovered) {
    final decurtazione = originalNet - totalRecovered;
    if (decurtazione.abs() < 0.009) return Colors.green.shade700;
    return Colors.red.shade700;
  }

  Widget _summaryRowTotaleRecupero({
    required double originalNet,
    required double totalRecovered,
    bool highlight = false,
  }) {
    final mainStyle = TextStyle(
      fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
      color: highlight ? _primaryBlue : Colors.black87,
      fontSize: highlight ? 16 : 14,
    );
    final decurtazioneStyle = TextStyle(
      fontWeight: FontWeight.w400,
      color: _decurtazioneParenthesisColor(originalNet, totalRecovered),
      fontSize: highlight ? 16 : 14,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              'Totale recupero piano',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: mainStyle,
                children: [
                  TextSpan(text: EuroFormat.format(totalRecovered)),
                  TextSpan(
                    text: ' ${_decurtazioneParenthesisText(originalNet, totalRecovered)}',
                    style: decurtazioneStyle,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dilazioneSintetica(_RepaymentInstallmentPlan plan) {
    return plan.structureLines(_metodo).join(' · ');
  }

  String _paymentInstrumentPlural(int count) {
    final isBollettino = _metodo == 'Bollettino';
    if (count == 1) {
      return isBollettino ? 'bollettino' : 'effetto';
    }
    return isBollettino ? 'bollettini' : 'effetti';
  }

  String _dilazionePhaseLine(_PracticeDilazionePhase phase) {
    final amountText = _RepaymentInstallmentPlan._formatInstallmentLineAmount(
      phase.installmentAmount,
    );
    final plural = _paymentInstrumentPlural(phase.paymentCount);
    final rateWord = phase.paymentCount == 1 ? 'rata' : 'rate';
    return '${phase.paymentCount} $plural da $amountText '
        '(dal ${_formatDate(phase.startDate)} – ${_formatDate(phase.endDate)} / '
        '${phase.paymentCount} $rateWord ${phase.rateFrequencyLabel})';
  }

  Widget _dilazionePhasesBlock(_PracticePdrSchedule practice) {
    final phases = practice.dilazionePhases;
    if (phases.isEmpty) {
      return Text(
        'Dilazioni: ${_dilazioneSintetica(practice.plan)}',
        style: const TextStyle(fontSize: 13, height: 1.45),
      );
    }

    const textStyle = TextStyle(fontSize: 13, height: 1.45);
    const indent = 68.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < phases.length; i++)
          Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : indent,
              bottom: i < phases.length - 1 ? 4 : 0,
            ),
            child: Text.rich(
              TextSpan(
                style: textStyle,
                children: [
                  if (i == 0)
                    const TextSpan(
                      text: 'Dilazione: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  TextSpan(text: _dilazionePhaseLine(phases[i])),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _pianoRientroSummaryCard(_PracticePdrSchedule practice) {
    final recovered = practice.totalRecovered;
    final original = practice.netAmount;
    final sottoRecupero = recovered + 0.009 < original;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primaryBlue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${practice.label}: ${EuroFormat.format(original)} da recuperare',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (sottoRecupero) ...[
            const SizedBox(height: 4),
            Text(
              'Recupero effettivo: ${EuroFormat.format(recovered)} '
              '(importo rateizzato può essere inferiore al debito originario)',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.orange.shade900,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Recupero effettivo: ${EuroFormat.format(recovered)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
            ),
          const SizedBox(height: 8),
          if (practice.accontoAmount > 0) ...[
            Text(
              'Acconto: ${EuroFormat.format(practice.accontoAmount)}',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 6),
          ],
          _dilazionePhasesBlock(practice),
          if (practice.dilazionePhases.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Inizio: ${_formatDate(practice.startDate)} — '
              'Fine: ${_formatDate(practice.endDate)}'
              '${_practicePhaseMonthsSuffix(practice)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _practicePaymentCadenceHint(practice),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _modulatedSummaryWidgets() {
    final mod = _modulatedPlan;
    if (mod == null) return const [];

    return [
      _summaryRow(
        'Durata fasi personalizzate',
        '${mod.modulatedMonths} mesi',
      ),
      _summaryRow(
        'Recupero fasi personalizzate',
        EuroFormat.format(mod.modulatedRecovered),
      ),
      _summaryRow(
        'Debito residuo dilazionato',
        EuroFormat.format(mod.residualDebt),
        highlight: true,
      ),
      _summaryRow(
        'Dilazioni sul residuo',
        '${mod.finalInstallmentCount}',
      ),
      _summaryRowTotaleRecupero(
        originalNet: mod.netAmountOriginal,
        totalRecovered: mod.totalRecovered,
        highlight: true,
      ),
      _summaryRow(
        'Numero rate totali',
        '${mod.totalInstallmentCount}',
        highlight: true,
      ),
      ..._summaryAccontoRowsBeforeStructure(),
      _summaryStructureRow(
        mod.phaseSummaryLines(_metodo, _formatDate),
      ),
      if (_dataFine != null)
        _summaryRow('Data fine piano', _formatDate(_dataFine!)),
      if (_matchedPdrBand != null)
        _summaryRow(
          'Fascia PDR',
          '${EuroFormat.format(_matchedPdrBand!.from.toDouble())} – '
          '${EuroFormat.format(_matchedPdrBand!.to.toDouble())} · '
          '${_matchedPdrBand!.installments} dilazioni max',
        ),
      if (_cappedToAvailableMonths && _matchedPdrBand != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            'Sul residuo sono state usate ${mod.finalInstallmentCount} dilazioni '
            'su ${_matchedPdrBand!.installments - mod.modulatedMonths} mesi '
            'residui della fascia (limite età: '
            '${_availablePlanMonths()} mesi disponibili).',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.red.shade800,
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Prima le rate scelte dal cliente (fino a 3 fasi), poi il debito '
          'residuo viene dilazionato sulle mensilità PDR ancora disponibili.',
          style: TextStyle(fontSize: 12, height: 1.45, color: Colors.grey.shade700),
        ),
      ),
    ];
  }

  List<Widget> _multiPracticeSummaryWidgets() {
    final multi = _multiPracticePlan;
    if (multi == null) return const [];

    return [
      _summaryRow(
        multi.monthlyParallel
            ? 'Importo mensile disponibile'
            : 'Rata mensile cliente',
        EuroFormat.format(multi.monthlyClientPayment),
        highlight: true,
      ),
      _summaryRow(
        'Giorno scadenza mensile',
        '${_dataInizio.day} (come data inizio)',
      ),
      _summaryRow(
        'Data fine complessiva',
        _formatDate(multi.overallEndDate),
        highlight: true,
      ),
      const SizedBox(height: 8),
      Text(
        'Modalità pagamento',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      const SizedBox(height: 4),
      for (final phase in multi.phaseDescriptions)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '• $phase',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.blue.shade900,
            ),
          ),
        ),
      const Divider(height: 20),
      Text(
        'Piani di rientro (dal più piccolo)',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Colors.grey.shade900,
        ),
      ),
      const SizedBox(height: 10),
      for (final practice in [...multi.practices]
        ..sort(_comparePracticeScheduleByNet))
        _pianoRientroSummaryCard(practice),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          multi.monthlyParallel
              ? 'Il cliente versa ${EuroFormat.format(multi.monthlyClientPayment)} '
                  'ogni mese calendario, ripartito in parti uguali tra i piani ancora '
                  'aperti (tutti pagano nello stesso mese). Alla chiusura del più piccolo '
                  'la quota si ridistribuisce sui restanti; sull\'ultimo piano resta '
                  'l\'intero importo mensile. Il totale rateizzato può essere inferiore '
                  'al debito originario. Limite età e dilazioni PDR non si applicano.'
              : 'Il cliente versa ${EuroFormat.format(multi.monthlyClientPayment)} ogni mese '
                  'calendario, assegnato a rotazione ai piani aperti: con 3 pratiche la cadenza '
                  'effettiva per ciascuna è trimestrale, con 2 bimestrale, con 1 sola pratica '
                  'residua mensile fino a chiusura. Il totale rateizzato può essere inferiore '
                  'al debito originario.',
          style: TextStyle(fontSize: 12, height: 1.45, color: Colors.grey.shade700),
        ),
      ),
    ];
  }

  Widget _tabOrder(num order, Widget child) => appTabOrder(order, child);

  /// Esclude testi e anteprime dall'ordine di tabulazione.
  Widget _skipFocus(Widget child) {
    return ExcludeFocus(child: child);
  }

  void _advanceFocus(BuildContext context, [VoidCallback? beforeAdvance]) {
    beforeAdvance?.call();
    FocusScope.of(context).nextFocus();
  }

  List<Widget> _summaryAccontoRowsBeforeStructure() {
    final acconto = EuroFormat.parse(_accontoCtrl.text) ?? 0;
    if (acconto <= 0) return const [];
    return [
      _summaryRow('Acconto', EuroFormat.format(acconto)),
    ];
  }

  Widget _summaryStructureRow(List<String> lines) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              'Struttura rate',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text(
                    line,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _grossDebtLabel() {
    final total = _totaleImporti();
    return total > 0 ? EuroFormat.format(total) : '—';
  }

  String _netDebtLabel() {
    if (!_showPdrFeedback) return '—';
    final netto = _netDebt();
    return netto > 0 ? EuroFormat.format(netto) : '—';
  }

  String _accontoLabel() {
    final acconto = EuroFormat.parse(_accontoCtrl.text);
    return acconto == null ? '—' : EuroFormat.format(acconto);
  }

  Widget _formCard(List<_CreditorOption> options) {
    return Card(
      color: AppCardTheme.surface,
      shape: AppCardTheme.shape,
      elevation: AppCardTheme.elevation,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader(
                title: 'Sviluppo piano di rientro',
                icon: Icons.trending_down_outlined,
                trailing: OutlinedButton.icon(
                  onPressed: _resetForm,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Resetta'),
                ),
              ),
              const SizedBox(height: 20),
              _tabOrder(
                1,
                _dropdown(
                  'Cadenza (da selezionare)',
                  _cadenza,
                  const [
                    'Mensile',
                    'Bimestrale',
                    'Trimestrale',
                    'Modulato',
                  ],
                  (v) => setState(() {
                    _cadenza = v;
                    _showPdrFeedback = true;
                    if (_parseBirthYear() != null) _showBirthYearInfo = true;
                    _resetCalcolo();
                    _syncMultiPracticePreview();
                    _modulatedValidationVisible = false;
                    _modulatedSizingError = null;
                    if (v == 'Modulato') {
                      _modulatedVisiblePhaseCount = 1;
                      _planSizingMode = _PlanSizingMode.automatic;
                    }
                    _showMultiPracticeAmountErrors =
                        _usesMultiPracticeForm &&
                            _emptyPracticeFieldIndexes.isNotEmpty;
                    if (v != 'Mensile') _monthlyPlanCount = 1;
                  }),
                ),
              ),
              if (_cadenza == 'Mensile')
                _tabOrder(1.5, _monthlyPlanCountSelector()),
              _tabOrder(2, _creditorDropdown(options)),
              if ((_cadenza == 'Mensile' && _monthlyPlanCount == 1) ||
                  _isModulatedCadenza)
                _tabOrder(
                  3,
                  _debtAmountField(
                    'Importo da rateizzare',
                    _importo1Ctrl,
                    errorText: _singlePracticeAmountError(),
                  ),
                ),
              if (_isMonthlyParallelMulti && _monthlyPlanCount >= 2) ...[
                _tabOrder(
                  3,
                  _debtAmountField(
                    'Importo da recuperare (pratica A)',
                    _importo1Ctrl,
                    errorText: _practiceFieldError(0),
                  ),
                ),
                _tabOrder(
                  4,
                  _debtAmountField(
                    'Importo da recuperare (pratica B)',
                    _importo2Ctrl,
                    errorText: _practiceFieldError(1),
                  ),
                ),
              ],
              if (_isMonthlyParallelMulti && _monthlyPlanCount == 3)
                _tabOrder(
                  5,
                  _debtAmountField(
                    'Importo da recuperare (pratica C)',
                    _importo3Ctrl,
                    errorText: _practiceFieldError(2),
                  ),
                ),
              if (_cadenza == 'Bimestrale') ...[
                _tabOrder(
                  3,
                  _debtAmountField(
                    'Importo da recuperare (pratica A)',
                    _importo1Ctrl,
                    errorText: _practiceFieldError(0),
                  ),
                ),
                _tabOrder(
                  4,
                  _debtAmountField(
                    'Importo da recuperare (pratica B)',
                    _importo2Ctrl,
                    errorText: _practiceFieldError(1),
                  ),
                ),
              ],
              if (_cadenza == 'Trimestrale') ...[
                _tabOrder(
                  3,
                  _debtAmountField(
                    'Importo da recuperare (pratica A)',
                    _importo1Ctrl,
                    errorText: _practiceFieldError(0),
                  ),
                ),
                _tabOrder(
                  4,
                  _debtAmountField(
                    'Importo da recuperare (pratica B)',
                    _importo2Ctrl,
                    errorText: _practiceFieldError(1),
                  ),
                ),
                _tabOrder(
                  5,
                  _debtAmountField(
                    'Importo da recuperare (pratica C)',
                    _importo3Ctrl,
                    errorText: _practiceFieldError(2),
                  ),
                ),
              ],
              if (_usesMultiPracticeForm)
                _skipFocus(_multiPracticeOrderPreview()),
              if (_usesMultiPracticeForm) ...[
                _tabOrder(
                  _monthlyParallelTabForSharedRate(),
                  _debtAmountField(
                    _isMonthlyParallelMulti
                        ? 'Importo mensile disponibile'
                        : 'Importo rata mensile (tutte le pratiche)',
                    _rataMensileCondivisaCtrl,
                  ),
                ),
                _skipFocus(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _monthlyParallelHelpText(),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ],
              _tabOrder(
                _usesMultiPracticeForm
                    ? _multiPracticeTabForAcconto()
                    : 4,
                _accontoField(),
              ),
              _skipFocus(_netDebtPdrFeedback()),
              if (!_usesMultiPracticeForm)
                _tabOrder(5, _birthYearAndMonthsRow()),
              _tabOrder(
                _usesMultiPracticeForm
                    ? _multiPracticeTabForDate()
                    : 6,
                _dateRow(),
              ),
              if (_isModulatedCadenza) ..._modulatedPhaseFormFields(),
              if (!_usesMultiPracticeForm) ...[
                _tabOrder(
                  _isModulatedCadenza ? _modulatedTabAfterPhases + 1 : 7,
                  _dropdown(
                    'Modalità rateizzazione',
                    _modalitaRateLabels[_modalitaRate]!,
                    _modalitaRateLabels.values.toList(),
                    (v) {
                      final mode = _modalitaRateLabels.entries
                          .firstWhere((e) => e.value == v)
                          .key;
                      setState(() {
                        _modalitaRate = mode;
                        _resetCalcolo();
                      });
                      _refreshModulatedValidation();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _isModulatedCadenza
                        ? 'Si applica alla dilazione del debito residuo, dopo le fasi '
                            'personalizzate scelte dal cliente.'
                        : _modalitaRate == _RepaymentSplitMode.allEqual
                            ? 'Ogni dilazione ha lo stesso importo in euro interi. '
                                'Il totale recuperato può essere leggermente inferiore '
                                'all\'importo netto, ma non lo supera mai.'
                            : 'Numero dilazioni = debito netto ÷ rata (arrotondato per eccesso). '
                                'Le prime n−1 rate seguono la rata scelta; l\'ultima '
                                'chiude il residuo con i centesimi fino all\'importo netto.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                if (!_isModulatedCadenza)
                  _tabOrder(
                    8,
                    _planSizingSection(),
                  ),
              ] else if (_isRotationMultiPractice)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Tutte le dilazioni uguali alla rata mensile. Il totale '
                    'rateizzato per ogni piano può essere leggermente inferiore '
                    'all\'importo da recuperare (nessima ultima rata di conguaglio).',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ..._paymentMethodFields(
                _usesMultiPracticeForm
                    ? _multiPracticeTabForPaymentMethod()
                    : (_isModulatedCadenza ? _modulatedTabAfterPhases + 2 : 9),
              ),
            if (_metodo == 'Cambiali')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Spese cambiali: 12 per mille (12‰) sull\'intero importo '
                  'dilazionato. Il costo totale compare nel riepilogo dopo '
                  'lo sviluppo del piano.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '* Compila i campi e usa il riepilogo per sviluppare il piano',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final months =
        _showBirthYearInfo ? _availablePlanMonths() : null;

    return Card(
      shape: AppCardTheme.shape,
      elevation: AppCardTheme.elevation,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              title: 'Riepilogo',
              icon: Icons.summarize_outlined,
            ),
            const SizedBox(height: 8),
            const Divider(),
            _summaryRow('Creditore', _creditor?.name ?? '—'),
            _summaryRow('Cadenza', _cadenza),
            if (!_usesMultiPracticeForm) ...[
              _summaryRow('Importo da rateizzare', _grossDebtLabel()),
              _summaryRow('Acconto', _accontoLabel()),
              _summaryRow('Importo netto', _netDebtLabel()),
            ] else ...[
              _summaryRow('Acconto', _accontoLabel()),
              if (_showPdrFeedback &&
                  (EuroFormat.parse(_accontoCtrl.text) ?? 0) > 0 &&
                  _multiPracticeFieldCount() > 0)
                _summaryRow(
                  'Acconto per pratica',
                  EuroFormat.format(
                    (EuroFormat.parse(_accontoCtrl.text) ?? 0) /
                        _multiPracticeFieldCount(),
                  ),
                ),
              if (_showPdrFeedback) ...[
                for (final debt in _practiceDebtsForCadenza())
                  if (debt.netAmount > 0)
                    _summaryRow(
                      debt.label,
                      EuroFormat.format(debt.netAmount),
                    ),
                if (EuroFormat.parse(_rataMensileCondivisaCtrl.text) != null)
                  _summaryRow(
                    _isMonthlyParallelMulti
                        ? 'Importo mensile disponibile'
                        : 'Rata mensile indicata',
                    EuroFormat.format(
                      EuroFormat.parse(_rataMensileCondivisaCtrl.text)!,
                    ),
                  ),
              ],
            ],
            if (!_usesMultiPracticeForm) ...[
              _summaryRow(
                'Anno di nascita',
                _birthYearCtrl.text.trim().isEmpty ? '—' : _birthYearCtrl.text,
              ),
              _summaryRow(
                'Mesi disponibili',
                !_showBirthYearInfo || months == null ? '—' : '$months',
                valueColor: _monthsBelowPdrSheetInstallments
                    ? Colors.red.shade700
                    : null,
              ),
              if (_monthsBelowPdrSheetInstallments &&
                  _pdrBandForCurrentNet() != null &&
                  months != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'I $months mesi disponibili sono inferiori alle '
                    '${_pdrBandForCurrentNet()!.installments} dilazioni previste '
                    'dalla fascia PDR: il calcolo userà al massimo $months dilazioni.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
            ],
            _summaryRow('Data inizio piano', _formatDate(_dataInizio)),
            _summaryRow('Metodo di pagamento', _metodo),
            if (!_usesMultiPracticeForm) ...[
              _summaryRow(
                'Modalità rateizzazione',
                _modalitaRateLabels[_modalitaRate]!,
              ),
              if (!_isModulatedCadenza)
                _summaryRow(
                  'Definizione dilazioni',
                  _planSizingMode == _PlanSizingMode.automatic
                      ? 'Automatica'
                      : (_manualTarget ==
                              _ManualSizingTarget.byInstallmentAmount
                          ? 'Manuale · importo rata'
                          : 'Manuale · numero dilazioni'),
                ),
            ],
            if (_calcolato) ...[
              const Divider(height: 24),
              if (_multiPracticePlan != null) ..._multiPracticeSummaryWidgets()
              else if (_modulatedPlan != null) ..._modulatedSummaryWidgets()
              else ...[
                _summaryRow(
                  'Numero rate',
                  _numeroRate.toString(),
                  highlight: true,
                ),
                if (_installmentPlan != null)
                  _summaryRowTotaleRecupero(
                    originalNet: _netto,
                    totalRecovered: _installmentPlan!.totalRecovered,
                  ),
                ..._summaryAccontoRowsBeforeStructure(),
                if (_installmentPlan != null)
                  _summaryStructureRow(
                    _installmentPlan!.structureLines(_metodo),
                  ),
                if (_dataFine != null)
                  _summaryRow('Data fine piano', _formatDate(_dataFine!)),
                if (_matchedPdrBand != null)
                  _summaryRow(
                    'Fascia PDR',
                    '${EuroFormat.format(_matchedPdrBand!.from.toDouble())} – '
                    '${EuroFormat.format(_matchedPdrBand!.to.toDouble())} · '
                    '${_matchedPdrBand!.installments} dilazioni max',
                  ),
                if (_cappedToAvailableMonths && _matchedPdrBand != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Piano calcolato su ${_installmentPlan?.installmentCount ?? _numeroRate} '
                      'dilazioni: limite imposto dai '
                      '${_availablePlanMonths()} mesi disponibili '
                      '(fascia PDR: ${_matchedPdrBand!.installments} dilazioni max).',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.red.shade800,
                      ),
                    ),
                  )
                else if (_installmentPlan?.cappedToMax == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Piano adeguato al massimo di dilazioni previste dalla '
                      'fascia PDR.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
              ],
              if (_metodo == 'Cambiali' && _importoDilazionato != null) ...[
                const Divider(height: 20),
                _summaryRow(
                  'Importo dilazionato',
                  EuroFormat.format(_importoDilazionato!),
                ),
                _summaryRow(
                  'Costo acquisizione cambiali',
                  EuroFormat.format(
                    _costoAcquisizioneCambiali(_importoDilazionato!),
                  ),
                  highlight: true,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Text(
                    'Costo totale al 12 per mille sull\'importo dilazionato: '
                    '12‰ × ${EuroFormat.format(_importoDilazionato!)} = '
                    '${EuroFormat.format(_costoAcquisizioneCambiali(_importoDilazionato!))}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
              if (_warningPdrAmount)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _creditor!.pdrBands.isEmpty
                        ? '⚠️ Nessuna fascia PDR configurata.'
                        : '⚠️ Importo netto fuori dai limiti PDR del creditore.',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              if (_warningEta)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '⚠️ La durata supera i mesi disponibili '
                    '(${_availablePlanMonths()}).',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _exportingCommissions || _incassoGiaRegistrato
                        ? null
                        : _aggiungiIncassoInProvvigioni,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryBlue,
                      disabledForegroundColor: Colors.grey.shade600,
                      side: WidgetStateBorderSide.resolveWith((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return BorderSide(color: Colors.grey.shade400);
                        }
                        return const BorderSide(color: _primaryBlue);
                      }),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _exportingCommissions
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.payments_outlined),
                    label: Text(
                      _exportingCommissions
                          ? 'Registrazione incassi...'
                          : _incassoGiaRegistrato
                              ? 'Incasso registrato'
                              : 'Aggiungi incasso',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<CommissionInstallmentPayment> _commissionPaymentSchedule() {
    final multi = _multiPracticePlan;
    if (multi != null && multi.calendar.isNotEmpty) {
      final byDate = <DateTime, double>{};
      for (final payment in multi.calendar) {
        final day = _dateOnly(payment.date);
        byDate[day] = (byDate[day] ?? 0) + payment.amount;
      }
      final dates = byDate.keys.toList()..sort();
      return [
        for (final date in dates)
          CommissionInstallmentPayment(date: date, amount: byDate[date]!),
      ];
    }

    final plan = _installmentPlan;
    if (plan != null && _numeroRate > 0) {
      final amounts = plan.installmentAmountsList;
      final monthStep = switch (_cadenza) {
        'Bimestrale' => 2,
        'Trimestrale' => 3,
        _ => 1,
      };
      return [
        for (var i = 0; i < amounts.length; i++)
          CommissionInstallmentPayment(
            date: addMonthsSameCalendarDay(_dataInizio, i * monthStep),
            amount: amounts[i],
          ),
      ];
    }

    return const [];
  }

  List<RepaymentPlanCommissionSlice> _commissionExportSlices() {
    final multi = _multiPracticePlan;
    if (multi != null) {
      return [
        for (final practice in multi.practices)
          RepaymentPlanCommissionSlice(
            planLabel: practice.label,
            pdrAmount: practice.totalRecovered,
            cashAmount: practice.accontoAmount,
          ),
      ];
    }

    final mod = _modulatedPlan;
    if (mod != null) {
      return [
        RepaymentPlanCommissionSlice(
          pdrAmount: mod.totalRecovered,
          cashAmount: EuroFormat.parse(_accontoCtrl.text) ?? 0,
        ),
      ];
    }

    final plan = _installmentPlan;
    if (plan != null) {
      return [
        RepaymentPlanCommissionSlice(
          pdrAmount: plan.totalRecovered,
          cashAmount: EuroFormat.parse(_accontoCtrl.text) ?? 0,
        ),
      ];
    }

    return const [];
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _hasFuturePlanPayments() {
    if (_dataFine != null && isPaymentAfterCurrentMonth(_dataFine!)) {
      return true;
    }
    final multi = _multiPracticePlan;
    if (multi != null) {
      return multi.calendar.any(
        (p) => isPaymentAfterCurrentMonth(p.date),
      );
    }
    return false;
  }

  bool get _incassoGiaRegistrato => _sessionCommissionDocIds.isNotEmpty;

  Future<void> _aggiungiIncassoInProvvigioni() async {
    final creditor = _creditor;
    final creditorId = _creditorId;
    if (!_calcolato || creditor == null || creditorId == null) return;
    if (_incassoGiaRegistrato) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Incasso già registrato per questo piano. '
            'Usa Annulla per eliminarlo prima di registrarne un altro.',
          ),
        ),
      );
      return;
    }

    final schedulePreview = _commissionPaymentSchedule();
    final dialogResult = await showCommissionExportDialog(
      context: context,
      hasPaymentsAfterCurrentMonth: _hasFuturePlanPayments(),
      scheduledPayments: [
        for (var i = 0; i < schedulePreview.length; i++)
          CommissionExportScheduleLine(
            date: schedulePreview[i].date,
            amount: schedulePreview[i].amount,
            label: schedulePreview.length > 1 ? 'Rata ${i + 1}' : null,
          ),
      ],
      description:
          'Verranno creati gli incassi con importo totale rateizzato '
          '(${_metodo == 'Bollettino' ? 'Pdr c/bollettini postali' : 'Pdr c/effetti cambiari'}) '
          'e, se presente, l\'acconto in contanti.',
    );

    if (dialogResult == null || !mounted) return;

    final companyName = dialogResult.companyName;
    final collectionDate = dialogResult.collectionDate;

    setState(() => _exportingCommissions = true);

    final RepaymentPlanCommissionExportResult result;
    if (dialogResult.dateMode == CommissionExportDateMode.respectSchedule) {
      final schedule = _commissionPaymentSchedule();
      final pdrKey =
          RepaymentPlanCommissionExporter.pdrCommissionKeyForPlanMethod(_metodo);
      if (schedule.isEmpty || pdrKey == null) {
        result = RepaymentPlanCommissionExportResult(
          savedCount: 0,
          errors: [
            if (pdrKey == null)
              'Metodo di pagamento piano non valido.'
            else
              'Impossibile ricavare le date delle rate per la registrazione.',
          ],
        );
      } else {
        var pdrResult =
            await RepaymentPlanCommissionExporter.saveInstallmentCollections(
          creditorId: creditorId,
          creditorName: creditor.name,
          companyName: companyName,
          paymentMethodKey: pdrKey,
          dateMode: CommissionExportDateMode.respectSchedule,
          singleCollectionDate: collectionDate,
          installments: schedule,
        );
        final acconto = EuroFormat.parse(_accontoCtrl.text) ?? 0;
        if (pdrResult.savedCount > 0 && acconto > 0.009) {
          final accontoResult =
              await RepaymentPlanCommissionExporter.saveInstallmentCollections(
            creditorId: creditorId,
            creditorName: creditor.name,
            companyName: companyName,
            paymentMethodKey: 'contanti',
            dateMode: CommissionExportDateMode.respectSchedule,
            singleCollectionDate: collectionDate,
            installments: [
              CommissionInstallmentPayment(
                date: schedule.first.date,
                amount: acconto,
              ),
            ],
          );
          pdrResult = RepaymentPlanCommissionExportResult(
            savedCount: pdrResult.savedCount + accontoResult.savedCount,
            errors: [...pdrResult.errors, ...accontoResult.errors],
            savedDocIds: [
              ...pdrResult.savedDocIds,
              ...accontoResult.savedDocIds,
            ],
          );
        }
        result = pdrResult;
      }
    } else {
      result = await RepaymentPlanCommissionExporter.saveAll(
        RepaymentPlanCommissionExportRequest(
          creditorId: creditorId,
          creditorName: creditor.name,
          planPaymentMethod: _metodo,
          companyName: companyName,
          collectionDate: collectionDate,
          slices: _commissionExportSlices(),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _exportingCommissions = false;
      if (result.savedDocIds.isNotEmpty) {
        _sessionCommissionDocIds.addAll(result.savedDocIds);
      }
    });

    if (result.savedCount > 0 && !result.hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.savedCount} '
            '${result.savedCount == 1 ? 'incasso registrato' : 'incassi registrati'} '
            'in provvigioni.',
          ),
        ),
      );
      return;
    }

    if (result.savedCount > 0 && result.hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.savedCount} incassi registrati. '
            '${result.errors.join(' ')}',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.errors.isNotEmpty
              ? result.errors.join('\n')
              : 'Nessun incasso registrato.',
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<bool> _deleteSessionCommissions() async {
    if (_sessionCommissionDocIds.isEmpty) return true;

    setState(() => _exportingCommissions = true);
    final deleteResult =
        await RepaymentPlanCommissionExporter.deleteRegisteredCollections(
      _sessionCommissionDocIds,
    );
    if (!mounted) return false;

    setState(() {
      _exportingCommissions = false;
      if (deleteResult.savedCount > 0) {
        _sessionCommissionDocIds.clear();
      }
    });

    if (deleteResult.savedCount == 0 && deleteResult.hasErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(deleteResult.errors.join(' '))),
      );
      return false;
    }

    if (deleteResult.savedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleteResult.savedCount == 1
                ? 'Incasso eliminato.'
                : '${deleteResult.savedCount} incassi eliminati.',
          ),
        ),
      );
    }
    return true;
  }

  Future<void> _annullaPiano() async {
    if (_sessionCommissionDocIds.isEmpty) {
      _exitPlanScreen();
      return;
    }

    final action = await showPlanCancelWithCommissionsDialog(
      context,
      registeredCount: _sessionCommissionDocIds.length,
    );
    if (!mounted) return;

    switch (action) {
      case null:
      case PlanCancelWithCommissionsAction.stay:
        return;
      case PlanCancelWithCommissionsAction.deleteAndStay:
        await _deleteSessionCommissions();
        return;
      case PlanCancelWithCommissionsAction.exitKeepCommissions:
        _exitPlanScreen();
        return;
      case PlanCancelWithCommissionsAction.exitDeleteCommissions:
        if (await _deleteSessionCommissions()) {
          _exitPlanScreen();
        }
        return;
    }
  }

  void _exitPlanScreen() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    _resetForm();
  }

  Widget _buildPlanActionBar(List<_CreditorOption> options) {
    return ListenableBuilder(
      listenable: _formAmountFieldsListenable,
      builder: (context, _) {
        final canDevelop = _canPressSviluppaPiano(options);
        return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _annullaPiano,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.close),
            label: const Text('Annulla'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: canDevelop ? _calcola : _revealRequiredFieldErrors,
            style: FilledButton.styleFrom(
              backgroundColor: ProjectColors.calc,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: Icon(_calcolato ? Icons.check_circle_outline : Icons.play_arrow),
            label: Text(_calcolato ? 'Piano sviluppato' : 'Sviluppa piano'),
          ),
        ),
      ],
    );
      },
    );
  }

  Widget _buildContent(List<_CreditorOption> options) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final scrollableColumns = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _formCard(options)),
            const SizedBox(width: 16),
            Expanded(
              child: KeyedSubtree(
                key: _summaryKey,
                child: _summaryCard(),
              ),
            ),
          ],
        );

        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: scrollableColumns,
                ),
              ),
              const SizedBox(height: 16),
              _buildPlanActionBar(options),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                controller: _mobileScrollController,
                children: [
                  _formCard(options),
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: _summaryKey,
                    child: _summaryCard(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            _buildPlanActionBar(options),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'Sviluppo piano di rientro',
      current: CreditCalcNavItem.develop,
      body: _cachedCreditorOptions == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(_cachedCreditorOptions!),
    );
  }

  List<Widget> _paymentMethodFields(int tabIndex) {
    if (_creditor == null) return [];

    final methods = _creditor!.availablePaymentMethods;
    if (methods.isNotEmpty &&
        (_metodo.isEmpty || !methods.contains(_metodo))) {
      _syncPaymentMethodForCreditor();
    }

    if (methods.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Nessuna modalità di pagamento abilitata per questo creditore. '
            'Configurale da Impostazioni → Creditori.',
            style: TextStyle(color: Colors.orange.shade800, fontSize: 14),
          ),
        ),
      ];
    }

    final metodo = methods.contains(_metodo) ? _metodo : methods.first;

    return [
      _tabOrder(
        tabIndex,
        _dropdown(
          'Metodo di pagamento',
          metodo,
          methods,
          (v) => setState(() {
            _metodo = v;
            _showPdrFeedback = true;
            if (_parseBirthYear() != null) _showBirthYearInfo = true;
            _resetCalcolo();
          }),
        ),
      ),
    ];
  }

  Widget _creditorDropdown(List<_CreditorOption> options) {
    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Nessun creditore registrato. Aggiungine uno da Impostazioni → Creditori.',
          style: TextStyle(color: Colors.orange.shade800, fontSize: 14),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: appTabFocusShell(
        context,
        child: DropdownButtonFormField<String>(
          value: _creditorId,
          items: options
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            final selected = options.firstWhere((o) => o.id == id);
            setState(() {
              _creditorId = id;
              _creditor = selected;
              _syncPaymentMethodForCreditor();
              _showPdrFeedback = true;
              if (_parseBirthYear() != null) _showBirthYearInfo = true;
              _resetCalcolo();
            });
            _refreshModulatedValidation();
          },
          decoration: appFormFieldDecoration(
            'Creditore',
            errorText: _creditorFieldError(),
          ),
        ),
      ),
    );
  }

  Widget _dateRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: appTabFocusShell(
        context,
        child: InkWell(
          onTap: _pickDataInizio,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: appFormFieldDecoration('Data inizio piano'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDate(_dataInizio)),
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _birthYearAndMonthsRow() {
    final months =
        _showBirthYearInfo ? _availablePlanMonths() : null;
    final ageYears = _showBirthYearInfo ? _debtorAgeYears() : null;
    final maxAge = _creditor?.maxAgePdr;
    final band = _pdrBandForCurrentNet();
    final belowPdr = _monthsBelowPdrSheetInstallments;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                child: appTabFocusShell(
                  context,
                  onFocusChange: (hasFocus) {
                    if (!hasFocus && !_isResettingForm) _commitBirthYear();
                  },
                  onCommit: _commitBirthYear,
                  child: TextField(
                    controller: _birthYearCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () =>
                        _advanceFocus(context, _commitBirthYear),
                    decoration: appFormFieldDecoration(
                      'Anno nascita',
                      errorText: _birthYearFieldError(),
                    ).copyWith(
                      hintText: '1980',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _skipFocus(
                  InputDecorator(
                  decoration: appFormFieldDecoration('Mesi disponibili').copyWith(
                    enabledBorder: belowPdr
                        ? OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red.shade400),
                          )
                        : null,
                  ),
                  child: Text(
                    !_showBirthYearInfo || months == null ? '—' : '$months',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: !_showBirthYearInfo || months == null
                          ? Colors.black45
                          : (belowPdr || months == 0
                              ? Colors.red.shade700
                              : Colors.black87),
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),
          if (_showBirthYearInfo && ageYears != null && maxAge != null)
            _skipFocus(
              Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Età $ageYears anni (anno in corso − nascita) · '
                'Mesi residui: ($maxAge − $ageYears) × 12 = ${months ?? '—'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            ),
          if (belowPdr && months != null && band != null)
            _skipFocus(
              Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'I $months mesi disponibili sono inferiori alle '
                '${band.installments} dilazioni previste dalla scheda creditore '
                '(fascia PDR). Il piano verrà calcolato al massimo su $months '
                'dilazioni, in base alle mensilità disponibili.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ),
        ],
      ),
    );
  }

  Widget _monthlyPlanCountSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Piani di rientro da chiudere',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1')),
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3')),
            ],
            selected: {_monthlyPlanCount},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              setState(() {
                _monthlyPlanCount = selection.first;
                _resetCalcolo();
                _syncMultiPracticePreview();
                _showMultiPracticeAmountErrors =
                    _usesMultiPracticeForm &&
                        _emptyPracticeFieldIndexes.isNotEmpty;
                if (_monthlyPlanCount == 1) {
                  _importo2Ctrl.clear();
                  _importo3Ctrl.clear();
                } else if (_monthlyPlanCount == 2) {
                  _importo3Ctrl.clear();
                }
              });
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  int _monthlyParallelTabForSharedRate() {
    if (_isMonthlyParallelMulti) {
      return _monthlyPlanCount == 3 ? 6 : 5;
    }
    return _cadenza == 'Trimestrale' ? 6 : 5;
  }

  int _multiPracticeTabForAcconto() {
    if (_isMonthlyParallelMulti) {
      return _monthlyPlanCount == 3 ? 7 : 6;
    }
    return _cadenza == 'Trimestrale' ? 7 : 6;
  }

  int _multiPracticeTabForDate() {
    if (_isMonthlyParallelMulti) {
      return _monthlyPlanCount == 3 ? 8 : 7;
    }
    return _cadenza == 'Trimestrale' ? 8 : 7;
  }

  int _multiPracticeTabForPaymentMethod() {
    if (_isMonthlyParallelMulti) {
      return _monthlyPlanCount == 3 ? 9 : 8;
    }
    return _cadenza == 'Trimestrale' ? 9 : 8;
  }

  String _monthlyParallelHelpText() {
    if (_isMonthlyParallelMulti) {
      return switch (_monthlyPlanCount) {
        2 =>
          'Due piani ordinati dal debito più piccolo (Piano 1 → 2). '
          'Ogni mese l\'importo disponibile è diviso in parti uguali tra i piani '
          'ancora aperti; alla chiusura del più piccolo la quota si ridistribuisce '
          'sul residuo. Non si applicano limite età né dilazioni PDR.',
        3 =>
          'Tre piani dal più piccolo al più grande. Stessa logica mensile: quota '
          'uguale su tutti i piani aperti, ridistribuzione progressiva fino '
          'all\'ultimo piano con l\'intero importo mensile.',
        _ => '',
      };
    }
    return _cadenza == 'Bimestrale'
        ? 'Due piani di rientro: calcolo e rotazione partono sempre '
            'dal debito più piccolo (Piano 1), poi il più grande. '
            'L\'ordine di inserimento nei campi non conta. Stessa rata '
            'mensile a turno; dilazioni tutte uguali.'
        : 'Tre piani di rientro: sempre ordinati dal debito più piccolo '
            'al più grande (Piano 1 → 2 → 3), indipendentemente dai campi. '
            'Stessa rata mensile a rotazione; dilazioni tutte uguali.';
  }

  /// Anteprima ordine piani (dal più piccolo) dopo immissione importi.
  Widget _multiPracticeOrderPreview() {
    if (!_showPdrFeedback) return const SizedBox.shrink();

    final debts = _previewOrderedDebts;
    if (debts.isEmpty || debts.every((d) => d.netAmount <= 0)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _primaryBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ordine di calcolo e riepilogo (dal più piccolo)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 6),
            for (final debt in debts)
              if (debt.netAmount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${debt.label}: ${EuroFormat.format(debt.netAmount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _netDebtPdrFeedback() {
    if (!_showPdrFeedback) return const SizedBox.shrink();

    final creditor = _creditor;
    final netto = _netDebt();
    if (creditor == null || netto <= 0) {
      return const SizedBox.shrink();
    }

    final minDebt = creditor.minDebtAmount;
    final maxDebt = creditor.maxDebtAmount;
    final band = creditor.bandForAmount(netto);

    if (creditor.pdrBands.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Configura le fasce PDR nella scheda del creditore per il confronto importi.',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
        ),
      );
    }

    Color tone;
    String message;
    if (minDebt != null && netto.round() < minDebt) {
      tone = Colors.red.shade700;
      message =
          'Importo netto ${EuroFormat.format(netto)} inferiore al minimo PDR '
          '(${EuroFormat.format(minDebt.toDouble())}).';
    } else if (maxDebt != null && netto.round() > maxDebt) {
      tone = Colors.red.shade700;
      message =
          'Importo netto ${EuroFormat.format(netto)} superiore al massimo PDR '
          '(${EuroFormat.format(maxDebt.toDouble())}).';
    } else if (band == null) {
      tone = Colors.red.shade700;
      message =
          'Importo netto ${EuroFormat.format(netto)} non rientra in nessuna fascia PDR '
          '(${EuroFormat.format(minDebt!.toDouble())} – '
          '${EuroFormat.format(maxDebt!.toDouble())}).';
    } else if (_usesMultiPracticeForm) {
      // Multi-pratica: il range PDR non vincola le dilazioni → nessun messaggio.
      return const SizedBox.shrink();
    } else {
      tone = Colors.green.shade800;
      final autoCount = _planSizingMode == _PlanSizingMode.automatic &&
              !_usesMultiPracticeForm &&
              !_isModulatedCadenza
          ? (_modalitaRate == _RepaymentSplitMode.lastAdjustment
              ? _RepaymentInstallmentPlan.installmentCountForLastAdjustment(
                  netAmount: netto,
                  minInstallment: creditor.minInstallmentAmount,
                )
              : _RepaymentInstallmentPlan.installmentCountForMinAmount(
                  netAmount: netto,
                  minInstallment: creditor.minInstallmentAmount,
                ))
          : null;
      final rateLabel = autoCount != null
          ? '$autoCount rate previste (minimo rata '
              '${EuroFormat.format(creditor.minInstallmentAmount)})'
          : '${band.installments} rate previste';
      message =
          'Importo netto ${EuroFormat.format(netto)} nella fascia PDR '
          '${EuroFormat.format(band.from.toDouble())} – '
          '${EuroFormat.format(band.to.toDouble())} · $rateLabel.';
    }

    final monthsNote = _monthsBelowPdrSheetInstallments &&
            band != null &&
            _availablePlanMonths() != null
        ? ' I ${_availablePlanMonths()} mesi disponibili sono inferiori alle '
            '${band.installments} dilazioni della scheda: il piano mensile '
            'verrà calcolato al massimo su ${_availablePlanMonths()} dilazioni.'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: TextStyle(fontSize: 13, height: 1.4, color: tone),
          ),
          if (monthsNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                monthsNote.trim(),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onManualFieldChanged() {
    final hadFeedback = _manualValidationVisible ||
        _manualSizingError != null ||
        _manualSizingHint != null;
    if (hadFeedback) {
      setState(() {
        _manualValidationVisible = false;
        _manualSizingError = null;
        _manualSizingHint = null;
      });
    }
    _resetCalcolo();
  }

  Widget _accontoField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: appTabFocusShell(
        context,
        onCommit: _commitAcconto,
        child: TextField(
          controller: _accontoCtrl,
          focusNode: _accontoFocusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onEditingComplete: () => _advanceFocus(context, _commitAcconto),
          decoration: appFormFieldDecoration('Acconto'),
        ),
      ),
    );
  }

  void _commitAmountField(TextEditingController controller) {
    if (_isResettingForm) return;
    final prior = controller.text;
    if (controller.text.trim().isEmpty) {
      controller.clear();
    } else {
      EuroFormat.applyToController(controller);
    }
    if (prior == controller.text && _showPdrFeedback) {
      _refreshMultiPracticeAmountErrors(showErrors: false);
      return;
    }
    _resetCalcoloIfNeeded();
    setState(() {
      _showPdrFeedback = true;
      if (_parseBirthYear() != null) _showBirthYearInfo = true;
      _refreshMultiPracticeAmountErrors();
      _syncMultiPracticePreview();
    });
    _refreshModulatedValidation();
  }

  Widget _debtAmountField(
    String label,
    TextEditingController controller, {
    String? errorText,
    VoidCallback? onBlur,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onChanged,
  }) {
    void commitField() {
      if (onEditingComplete != null) {
        onEditingComplete();
      } else if (onBlur != null) {
        onBlur();
      } else {
        _commitAmountField(controller);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: appTabFocusShell(
        context,
        onFocusChange: (hasFocus) {
          if (!hasFocus && !_isResettingForm) commitField();
        },
        onCommit: commitField,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
          onEditingComplete: () => _advanceFocus(context, commitField),
          decoration: appFormFieldDecoration(label, errorText: errorText),
        ),
      ),
    );
  }

  Widget _manualDesiredAmountField({String? errorText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: appTabFocusShell(
        context,
        onFocusChange: (hasFocus) {
          if (!hasFocus) _commitManualValidation();
        },
        onCommit: _commitManualValidation,
        child: TextField(
          key: const ValueKey('manual_desired_installment'),
          controller: _desiredInstallmentCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (_) => _onManualFieldChanged(),
          onEditingComplete: () => _advanceFocus(context, _commitManualValidation),
          decoration: appFormFieldDecoration(
            'Importo rata desiderato',
            errorText: errorText,
          ),
        ),
      ),
    );
  }

  Widget _manualInstallmentCountField({String? errorText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: appTabFocusShell(
        context,
        onFocusChange: (hasFocus) {
          if (!hasFocus) _commitManualValidation();
        },
        onCommit: _commitManualValidation,
        child: TextField(
          key: const ValueKey('manual_desired_installment_count'),
          controller: _desiredInstallmentCountCtrl,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          onChanged: (_) => _onManualFieldChanged(),
          onEditingComplete: () => _advanceFocus(context, _commitManualValidation),
          decoration: appFormFieldDecoration(
            'Numero dilazioni desiderato',
            errorText: errorText,
          ),
        ),
      ),
    );
  }

  List<Widget> _modulatedPhaseFormFields() {
    final widgets = <Widget>[
      _skipFocus(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Rate personalizzate (max $_maxModulatedPhases fasi). Con una sola fase '
            'usa Sviluppa piano; aggiungi altre fasi solo se servono ulteriori '
            'mensilità a importo ridotto.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ),
    ];

    var tab = 7;
    for (var i = 0; i < _modulatedVisiblePhaseCount; i++) {
      if (i > 0) {
        widgets.add(
          _skipFocus(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Fase ${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ),
        );
      }
      widgets.add(
        _modulatedPhaseRow(
          phaseIndex: i,
          tabMonths: tab++,
          tabAmount: tab++,
        ),
      );
    }

    if (_modulatedValidationVisible && _modulatedSizingError != null) {
      widgets.add(_modulatedPhaseValidationAlert());
    }

    if (_modulatedVisiblePhaseCount < _maxModulatedPhases) {
      widgets.add(
        _skipFocus(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: _addModulatedPhase,
                icon: const Icon(Icons.add),
                tooltip: 'Aggiungi altra fase a rata ridotta',
                style: IconButton.styleFrom(
                  backgroundColor: _primaryBlue.withValues(alpha: 0.08),
                  foregroundColor: _primaryBlue,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _modulatedPhaseValidationAlert() {
    return _skipFocus(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              size: 18,
              color: Colors.red.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _modulatedSizingError!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modulatedPhaseRow({
    required int phaseIndex,
    required int tabMonths,
    required int tabAmount,
  }) {
    final pair = _allModulatedPhaseControllers[phaseIndex];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _tabOrder(
              tabMonths,
              _modulatedMonthsField(
                pair.months,
                'Numero di mesi',
                wrapPadding: false,
                errorText: _modulatedMonthsError(phaseIndex),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _tabOrder(
              tabAmount,
              _modulatedAmountField(
                pair.amount,
                'Importo rata mensile',
                wrapPadding: false,
                errorText: _modulatedAmountError(phaseIndex),
              ),
            ),
          ),
          if (phaseIndex > 0) ...[
            const SizedBox(width: 12),
            _skipFocus(
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconButton(
                  onPressed: () => _removeModulatedPhaseAt(phaseIndex),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Rimuovi questa fase',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modulatedMonthsField(
    TextEditingController controller,
    String label, {
    bool wrapPadding = true,
    String? errorText,
  }) {
    final field = appTabFocusShell(
      context,
      onCommit: _commitModulatedValidation,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        onChanged: (_) => _onModulatedFieldChanged(),
        onEditingComplete: () =>
            _advanceFocus(context, _commitModulatedValidation),
        decoration: appFormFieldDecoration(label, errorText: errorText),
      ),
    );
    if (!wrapPadding) return field;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: field,
    );
  }

  Widget _modulatedAmountField(
    TextEditingController controller,
    String label, {
    bool wrapPadding = true,
    String? errorText,
  }) {
    final field = appTabFocusShell(
      context,
      onCommit: _commitModulatedValidation,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        onChanged: (_) => _onModulatedFieldChanged(),
        onEditingComplete: () =>
            _advanceFocus(context, _commitModulatedValidation),
        decoration: appFormFieldDecoration(label, errorText: errorText),
      ),
    );
    if (!wrapPadding) {
      return field;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: field,
    );
  }

  Widget _planSizingSection({bool modulatedResidual = false}) {
    final showManualError =
        _planSizingMode == _PlanSizingMode.manual &&
        _manualValidationVisible &&
        _manualSizingError != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            modulatedResidual
                ? 'Definizione dilazioni sul residuo'
                : 'Definizione dilazioni',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<_PlanSizingMode>(
            segments: const [
              ButtonSegment(
                value: _PlanSizingMode.automatic,
                label: Text('Automatico'),
                icon: Icon(Icons.auto_fix_high_outlined, size: 18),
              ),
              ButtonSegment(
                value: _PlanSizingMode.manual,
                label: Text('Manuale'),
                icon: Icon(Icons.tune_outlined, size: 18),
              ),
            ],
            selected: {_planSizingMode},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              setState(() {
                _planSizingMode = selection.first;
                _manualValidationVisible = false;
                _manualSizingError = null;
                _manualSizingHint = null;
                _resetCalcolo();
              });
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (_planSizingMode == _PlanSizingMode.manual) ...[
            const SizedBox(height: 14),
            Text(
              'Parametro manuale (scegline uno)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _manualTargetTile(
                    target: _ManualSizingTarget.byInstallmentAmount,
                    icon: Icons.euro_outlined,
                    title: 'Importo rata',
                    subtitle: 'Calcola le dilazioni in base alla rata desiderata',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _manualTargetTile(
                    target: _ManualSizingTarget.byInstallmentCount,
                    icon: Icons.calendar_view_month_outlined,
                    title: 'N. dilazioni',
                    subtitle: 'Imposta quante rate compongono il piano',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_manualTarget == _ManualSizingTarget.byInstallmentAmount)
              _manualDesiredAmountField(
                errorText: showManualError &&
                        _manualTarget == _ManualSizingTarget.byInstallmentAmount
                    ? _manualSizingError
                    : null,
              )
            else
              _manualInstallmentCountField(
                errorText: showManualError &&
                        _manualTarget == _ManualSizingTarget.byInstallmentCount
                    ? _manualSizingError
                    : null,
              ),
            if (_manualValidationVisible &&
                _manualSizingHint != null &&
                _planSizingMode == _PlanSizingMode.manual)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _manualSizingHint!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _manualTargetHint() {
    final n = _resolvedManualInstallmentCount();
    if (n == null) return '';

    if (_isMultiPracticeCadenza) {
      return 'Verranno generate $n dilazioni uguali da '
          '${EuroFormat.format(EuroFormat.parse(_rataMensileCondivisaCtrl.text) ?? 0)}.';
    }

    if (_modalitaRate == _RepaymentSplitMode.lastAdjustment && n > 1) {
      final netto = _netDebt();
      if (netto <= 0) {
        return 'Verranno generate $n dilazioni con ultima rata di conguaglio.';
      }
      final totalCents = (netto * 100).round();
      final desired = _manualTarget == _ManualSizingTarget.byInstallmentAmount
          ? EuroFormat.parse(_desiredInstallmentCtrl.text)
          : null;
      final equalCents = desired != null && desired > 0
          ? (desired * 100).round()
          : (netto / n).floor() * 100;
      final lastCents = totalCents - equalCents * (n - 1);
      return '${n - 1} dilazioni da ${EuroFormat.format(equalCents / 100)} + '
          '1 di conguaglio da ${EuroFormat.format(lastCents / 100)} '
          '(totale ${EuroFormat.format(netto)}).';
    }

    return 'Verranno generate $n dilazioni secondo la modalità rateizzazione scelta.';
  }

  Widget _manualTargetTile({
    required _ManualSizingTarget target,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _manualTarget == target;
    final borderColor =
        selected ? _primaryBlue : Colors.grey.shade400;
    final fill = selected ? _primaryBlue.withValues(alpha: 0.08) : null;

    return Material(
      color: fill ?? Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          setState(() {
            _manualTarget = target;
            _manualValidationVisible = false;
            _manualSizingError = null;
            _manualSizingHint = null;
            if (target == _ManualSizingTarget.byInstallmentAmount) {
              _desiredInstallmentCountCtrl.clear();
            } else {
              _desiredInstallmentCtrl.clear();
            }
            _resetCalcolo();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? _primaryBlue : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected ? _primaryBlue : Colors.black87,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, size: 18, color: _primaryBlue),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> onChanged, {
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: appTabFocusShell(
        context,
        child: DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          decoration: appFormFieldDecoration(label, errorText: errorText),
        ),
      ),
    );
  }

}
