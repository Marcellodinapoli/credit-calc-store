import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/euro_format.dart';

class CommissionEntryRecord {
  final String id;
  final Map<String, dynamic> data;

  const CommissionEntryRecord({required this.id, required this.data});
}

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

  static List<CommissionEntryRecord> commissionEntries(
    List<CommissionEntryRecord> records,
  ) {
    return records
        .where((record) => (record.data['type'] ?? '') == 'commission_entry')
        .toList();
  }

  static Set<CommissionMonthKey> availableMonths(
    List<CommissionEntryRecord> entries,
  ) {
    final months = <CommissionMonthKey>{};
    for (final entry in entries) {
      final date = entryDate(entry.data);
      if (date != null) months.add(CommissionMonthKey.fromDate(date));
    }
    return months;
  }

  /// Mese predefinito per i filtri provvigioni (mese di calendario in corso).
  static CommissionMonthKey defaultFilterMonth([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return CommissionMonthKey.fromDate(now);
  }

  /// Mesi con almeno un incasso, dal più recente al più vecchio.
  static List<CommissionMonthKey> monthsForFilter(
    List<CommissionEntryRecord> entries,
  ) {
    return availableMonths(entries).toList()
      ..sort((a, b) {
        if (a.year != b.year) return b.year.compareTo(a.year);
        return b.month.compareTo(a.month);
      });
  }

  /// Opzioni del filtro mese: mesi con incassi + mese corrente se ancora senza dati.
  static List<CommissionMonthKey> monthsForDropdown(
    List<CommissionEntryRecord> entries, {
    DateTime? reference,
  }) {
    final months = monthsForFilter(entries);
    final current = defaultFilterMonth(reference);
    if (months.contains(current)) return months;
    return [current, ...months];
  }

  static bool _matchesMonthFilter(DateTime date, CommissionMonthKey? month) {
    if (month == null) return true;
    return CommissionMonthKey.fromDate(date) == month;
  }

  static List<String> companyNamesInMonth(
    List<CommissionEntryRecord> entries,
    CommissionMonthKey? month,
  ) {
    final names = <String>{};
    for (final entry in entries) {
      final data = entry.data;
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

  static List<CommissionEntryRecord> filterDocs(
    List<CommissionEntryRecord> entries, {
    CommissionMonthKey? month,
    String? selectedCompanyName,
    String? paymentLabelFilter,
    String? selectedCreditorName,
  }) {
    return entries.where((entry) {
      final data = entry.data;
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

  static List<String> paymentLabelsInMonth(
    List<CommissionEntryRecord> entries,
    CommissionMonthKey? month,
  ) {
    final labels = <String>{};
    for (final entry in entries) {
      final data = entry.data;
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
    List<CommissionEntryRecord> entries,
    CommissionMonthKey? month,
  ) {
    final names = <String>{};
    for (final entry in entries) {
      final data = entry.data;
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
    List<CommissionEntryRecord> entries,
    String creditorId,
  ) =>
      entries
          .where(
            (entry) =>
                (entry.data['type'] ?? '') == 'commission_entry' &&
                (entry.data['creditorId'] ?? '').toString() == creditorId,
          )
          .length;

  static double totalCollected(
    List<CommissionEntryRecord> entries,
  ) =>
      entries.fold(
        0,
        (total, entry) => total + numField(entry.data, 'amountCollected'),
      );

  static double entryCommissionTotal(Map<String, dynamic> data) {
    final total = data['totalCommissionAmount'];
    if (total is num) return total.toDouble();

    final base = numField(data, 'commissionAmount');
    final incentive = numField(data, 'incentiveAmount');
    return base + (incentive != 0 ? incentive : 0);
  }

  static double totalCommission(
    List<CommissionEntryRecord> entries,
  ) =>
      entries.fold(
        0,
        (total, entry) => total + entryCommissionTotal(entry.data),
      );

  static List<CommissionPaymentTypeTotals> totalsByPaymentType(
    List<CommissionEntryRecord> entries,
  ) {
    final grouped = <String, CommissionPaymentTypeTotals>{};

    for (final entry in entries) {
      final data = entry.data;
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
