import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:credit_calc_core/credit_calc_core.dart' show EuroFormat;

import '../../offline/repository/credit_calc_repository.dart';

class CommissionMonthKey {
  final int year;
  final int month;

  const CommissionMonthKey(this.year, this.month);

  factory CommissionMonthKey.fromDate(DateTime date) =>
      CommissionMonthKey(date.year, date.month);

  DateTime get date => DateTime(year, month);

  @override
  bool operator ==(Object other) =>
      other is CommissionMonthKey &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

abstract final class CommissionCollectionsHelper {
  static const monthNames = [
    '',
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  static String monthLabel(CommissionMonthKey key) =>
      '${monthNames[key.month]} ${key.year}';

  static String formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  static DateTime? entryDate(Map<String, dynamic> data) {
    final collectionDate = data['collectionDate'];
    if (collectionDate is Timestamp) return collectionDate.toDate();

    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();

    return null;
  }

  static double numField(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  static String formatEuro(double value) => EuroFormat.format(value);

  static String companyName(Map<String, dynamic> data) =>
      (data['companyName'] ?? '').toString().trim();

  static String paymentLabel(Map<String, dynamic> data) =>
      (data['paymentMethodLabel'] ?? '').toString().trim();

  static String creditorName(Map<String, dynamic> data) =>
      (data['creditorName'] ?? '').toString().trim();

  static List<QueryDocumentSnapshot<Map<String, dynamic>>> commissionDocs(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    return (snapshot?.docs ?? [])
        .where((doc) => (doc.data()['type'] ?? '') == 'commission_entry')
        .toList();
  }

  static List<CreditCalcRecord> commissionRecords(
    List<CreditCalcRecord>? records,
  ) {
    return (records ?? [])
        .where((r) => (r.data['type'] ?? '') == 'commission_entry')
        .toList();
  }

  static Set<CommissionMonthKey> availableMonths(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final months = <CommissionMonthKey>{};
    for (final doc in docs) {
      final date = entryDate(doc.data());
      if (date != null) months.add(CommissionMonthKey.fromDate(date));
    }
    return months;
  }

  static Set<CommissionMonthKey> availableMonthsFromRecords(
    List<CreditCalcRecord> docs,
  ) {
    final months = <CommissionMonthKey>{};
    for (final doc in docs) {
      final date = entryDate(doc.data);
      if (date != null) months.add(CommissionMonthKey.fromDate(date));
    }
    return months;
  }

  /// Mese di calendario in corso.
  static CommissionMonthKey get currentMonth =>
      CommissionMonthKey.fromDate(DateTime.now());

  /// Mesi con almeno un incasso, dal più recente al più vecchio.
  static List<CommissionMonthKey> monthsForFilter(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return availableMonths(docs).toList()
      ..sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });
  }

  static List<CommissionMonthKey> monthsForFilterRecords(
    List<CreditCalcRecord> docs,
  ) {
    return availableMonthsFromRecords(docs).toList()
      ..sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });
  }

  /// Opzioni filtro mese: sempre il mese in corso + mesi con incassi.
  static List<CommissionMonthKey> monthsForFilterDropdown(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final months = monthsForFilter(docs);
    final now = currentMonth;
    if (months.isEmpty) return [now];
    if (months.contains(now)) return months;
    return [now, ...months];
  }

  static List<CommissionMonthKey> monthsForFilterDropdownRecords(
    List<CreditCalcRecord> docs,
  ) {
    final months = monthsForFilterRecords(docs);
    final now = currentMonth;
    if (months.isEmpty) return [now];
    if (months.contains(now)) return months;
    return [now, ...months];
  }

  static bool _matchesMonthFilter(DateTime date, CommissionMonthKey? month) {
    if (month == null) return true;
    return CommissionMonthKey.fromDate(date) == month;
  }

  static List<String> companyNamesInMonth(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    CommissionMonthKey? month,
  ) {
    final names = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      final date = entryDate(data);
      if (date == null) continue;
      if (!_matchesMonthFilter(date, month)) continue;
      final name = companyName(data);
      if (name.isNotEmpty) names.add(name);
    }
    final sorted = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  static List<QueryDocumentSnapshot<Map<String, dynamic>>> filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    CommissionMonthKey? month,
    String? selectedCompanyName,
    String? paymentLabelFilter,
    String? selectedCreditorName,
  }) {
    return docs.where((doc) {
      final data = doc.data();
      final date = entryDate(data);
      if (date == null) return false;
      if (!_matchesMonthFilter(date, month)) return false;

      if (selectedCompanyName != null &&
          selectedCompanyName.isNotEmpty &&
          companyName(data) != selectedCompanyName) {
        return false;
      }

      if (paymentLabelFilter != null &&
          paymentLabelFilter.isNotEmpty &&
          paymentLabel(data) != paymentLabelFilter) {
        return false;
      }

      if (selectedCreditorName != null &&
          selectedCreditorName.isNotEmpty &&
          creditorName(data) != selectedCreditorName) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final da = entryDate(a.data());
        final db = entryDate(b.data());
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
  }

  static List<String> paymentLabelsInMonth(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    CommissionMonthKey? month,
  ) {
    final labels = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      final date = entryDate(data);
      if (date == null) continue;
      if (!_matchesMonthFilter(date, month)) continue;
      final label = paymentLabel(data);
      if (label.isNotEmpty) labels.add(label);
    }
    final sorted = labels.toList()..sort();
    return sorted;
  }

  static List<String> creditorNamesInMonth(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    CommissionMonthKey? month,
  ) {
    final names = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      final date = entryDate(data);
      if (date == null) continue;
      if (!_matchesMonthFilter(date, month)) continue;
      final name = creditorName(data);
      if (name.isNotEmpty) names.add(name);
    }
    final sorted = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  static int countLinkedIncassi(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String creditorId,
  ) =>
      docs
          .where(
            (doc) =>
                (doc.data()['type'] ?? '') == 'commission_entry' &&
                (doc.data()['creditorId'] ?? '').toString() == creditorId,
          )
          .length;

  static int countLinkedIncassiRecords(
    List<CreditCalcRecord> docs,
    String creditorId,
  ) =>
      docs
          .where(
            (doc) =>
                (doc.data['type'] ?? '') == 'commission_entry' &&
                (doc.data['creditorId'] ?? '').toString() == creditorId,
          )
          .length;

  static List<CreditCalcRecord> filterRecords(
    List<CreditCalcRecord> docs, {
    CommissionMonthKey? month,
    String? selectedCompanyName,
    String? paymentLabelFilter,
    String? selectedCreditorName,
  }) {
    return docs.where((doc) {
      final data = doc.data;
      final date = entryDate(data);
      if (date == null) return false;
      if (!_matchesMonthFilter(date, month)) return false;

      if (selectedCompanyName != null &&
          selectedCompanyName.isNotEmpty &&
          companyName(data) != selectedCompanyName) {
        return false;
      }

      if (paymentLabelFilter != null &&
          paymentLabelFilter.isNotEmpty &&
          paymentLabel(data) != paymentLabelFilter) {
        return false;
      }

      if (selectedCreditorName != null &&
          selectedCreditorName.isNotEmpty &&
          creditorName(data) != selectedCreditorName) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final da = entryDate(a.data);
        final db = entryDate(b.data);
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
  }

  static List<String> companyNamesInMonthRecords(
    List<CreditCalcRecord> docs,
    CommissionMonthKey? month,
  ) {
    final names = <String>{};
    for (final doc in docs) {
      final data = doc.data;
      final date = entryDate(data);
      if (date == null) continue;
      if (!_matchesMonthFilter(date, month)) continue;
      final name = companyName(data);
      if (name.isNotEmpty) names.add(name);
    }
    final sorted = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  static List<String> paymentLabelsInMonthRecords(
    List<CreditCalcRecord> docs,
    CommissionMonthKey? month,
  ) {
    final labels = <String>{};
    for (final doc in docs) {
      final data = doc.data;
      final date = entryDate(data);
      if (date == null) continue;
      if (!_matchesMonthFilter(date, month)) continue;
      final label = paymentLabel(data);
      if (label.isNotEmpty) labels.add(label);
    }
    final sorted = labels.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  static List<String> creditorNamesInMonthRecords(
    List<CreditCalcRecord> docs,
    CommissionMonthKey? month,
  ) {
    final names = <String>{};
    for (final doc in docs) {
      final data = doc.data;
      final date = entryDate(data);
      if (date == null) continue;
      if (!_matchesMonthFilter(date, month)) continue;
      final name = creditorName(data);
      if (name.isNotEmpty) names.add(name);
    }
    final sorted = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  static double totalCollectedRecords(List<CreditCalcRecord> docs) =>
      docs.fold(0, (total, doc) => total + numField(doc.data, 'amountCollected'));

  static double totalCommissionRecords(List<CreditCalcRecord> docs) =>
      docs.fold(
        0,
        (total, doc) => total + entryCommissionTotal(doc.data),
      );

  static double totalCollected(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) =>
      docs.fold(0, (total, doc) => total + numField(doc.data(), 'amountCollected'));

  static double entryCommissionTotal(Map<String, dynamic> data) {
    final total = data['totalCommissionAmount'];
    if (total is num) return total.toDouble();

    final base = numField(data, 'commissionAmount');
    final incentive = numField(data, 'incentiveAmount');
    return base + (incentive != 0 ? incentive : 0);
  }

  static double totalCommission(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) =>
      docs.fold(
        0,
        (total, doc) => total + entryCommissionTotal(doc.data()),
      );

  static List<CommissionPaymentTypeTotals> totalsByPaymentType(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final grouped = <String, CommissionPaymentTypeTotals>{};

    for (final doc in docs) {
      final data = doc.data();
      final label = paymentLabel(data);
      final key = label.isEmpty ? 'Non specificata' : label;

      final existing = grouped[key];
      final commissionTotal = entryCommissionTotal(data);
      if (existing == null) {
        grouped[key] = CommissionPaymentTypeTotals(
          label: key,
          collected: numField(data, 'amountCollected'),
          commission: commissionTotal,
          practiceCount: 1,
        );
      } else {
        grouped[key] = CommissionPaymentTypeTotals(
          label: key,
          collected: existing.collected + numField(data, 'amountCollected'),
          commission: existing.commission + commissionTotal,
          practiceCount: existing.practiceCount + 1,
        );
      }
    }

    final sorted = grouped.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return sorted;
  }

  static List<CommissionPaymentTypeTotals> totalsByPaymentTypeRecords(
    List<CreditCalcRecord> docs,
  ) {
    final grouped = <String, CommissionPaymentTypeTotals>{};

    for (final doc in docs) {
      final data = doc.data;
      final label = paymentLabel(data);
      final key = label.isEmpty ? 'Non specificata' : label;

      final existing = grouped[key];
      final commissionTotal = entryCommissionTotal(data);
      if (existing == null) {
        grouped[key] = CommissionPaymentTypeTotals(
          label: key,
          collected: numField(data, 'amountCollected'),
          commission: commissionTotal,
          practiceCount: 1,
        );
      } else {
        grouped[key] = CommissionPaymentTypeTotals(
          label: key,
          collected: existing.collected + numField(data, 'amountCollected'),
          commission: existing.commission + commissionTotal,
          practiceCount: existing.practiceCount + 1,
        );
      }
    }

    final sorted = grouped.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return sorted;
  }
}

class CommissionPaymentTypeTotals {
  final String label;
  final double collected;
  final double commission;
  final int practiceCount;

  const CommissionPaymentTypeTotals({
    required this.label,
    required this.collected,
    required this.commission,
    required this.practiceCount,
  });
}
