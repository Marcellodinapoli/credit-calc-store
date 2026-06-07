import 'package:cloud_firestore/cloud_firestore.dart';

import 'commission_collections_shared.dart';

class CommissionPeriodTotals {
  final double collected;
  final double commission;
  final int practiceCount;

  const CommissionPeriodTotals({
    this.collected = 0,
    this.commission = 0,
    this.practiceCount = 0,
  });

  static const zero = CommissionPeriodTotals();
}

double? commissionPercentChange(double current, double previous) {
  if (previous.abs() < 0.009) {
    if (current.abs() < 0.009) return 0;
    return null;
  }
  return ((current - previous) / previous) * 100;
}

abstract final class CommissionStatisticsHelper {
  static CommissionPeriodTotals totalsForDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return CommissionPeriodTotals.zero;
    return CommissionPeriodTotals(
      collected: CommissionCollectionsHelper.totalCollected(docs),
      commission: CommissionCollectionsHelper.totalCommission(docs),
      practiceCount: docs.length,
    );
  }

  static Map<CommissionMonthKey, CommissionPeriodTotals> totalsByMonth(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final grouped = <CommissionMonthKey, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in docs) {
      final date = CommissionCollectionsHelper.entryDate(doc.data());
      if (date == null) continue;
      final key = CommissionMonthKey.fromDate(date);
      grouped.putIfAbsent(key, () => []).add(doc);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: totalsForDocs(entry.value),
    };
  }

  static Map<int, CommissionPeriodTotals> totalsByYear(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final grouped = <int, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in docs) {
      final date = CommissionCollectionsHelper.entryDate(doc.data());
      if (date == null) continue;
      grouped.putIfAbsent(date.year, () => []).add(doc);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: totalsForDocs(entry.value),
    };
  }

  static CommissionMonthKey previousMonth(CommissionMonthKey key) {
    if (key.month > 1) return CommissionMonthKey(key.year, key.month - 1);
    return CommissionMonthKey(key.year - 1, 12);
  }

  static String shortMonthLabel(
    CommissionMonthKey key, {
    bool omitYear = false,
  }) {
    final name = CommissionCollectionsHelper.monthNames[key.month];
    if (name.isEmpty) return omitYear ? '' : '${key.year}';
    final short = name.length >= 3 ? name.substring(0, 3) : name;
    if (omitYear) return short;
    return '$short ${key.year % 100}';
  }

  /// Mesi dell'anno [year] con almeno un incasso, più il mese in corso se è lo stesso anno.
  static List<({CommissionMonthKey key, CommissionPeriodTotals totals})>
      monthsInYearWithIncassi(
    Map<CommissionMonthKey, CommissionPeriodTotals> byMonth, {
    int? year,
  }) {
    final targetYear = year ?? DateTime.now().year;
    final now = CommissionMonthKey.fromDate(DateTime.now());

    final keys = <CommissionMonthKey>{
      for (final key in byMonth.keys)
        if (key.year == targetYear &&
            (byMonth[key]?.practiceCount ?? 0) > 0)
          key,
      if (now.year == targetYear) now,
    }.toList()
      ..sort((a, b) {
        if (a.year != b.year) return a.year.compareTo(b.year);
        return a.month.compareTo(b.month);
      });

    return [
      for (final key in keys)
        (key: key, totals: byMonth[key] ?? CommissionPeriodTotals.zero),
    ];
  }

  static List<({CommissionMonthKey key, CommissionPeriodTotals totals})>
      recentMonths(
    Map<CommissionMonthKey, CommissionPeriodTotals> byMonth, {
    int count = 6,
  }) {
    final keys = byMonth.keys.toList()
      ..sort((a, b) {
        if (a.year != b.year) return a.year.compareTo(b.year);
        return a.month.compareTo(b.month);
      });
    final slice = keys.length <= count ? keys : keys.sublist(keys.length - count);
    return [
      for (final key in slice)
        (key: key, totals: byMonth[key] ?? CommissionPeriodTotals.zero),
    ];
  }

  static List<({int year, CommissionPeriodTotals totals})> recentYears(
    Map<int, CommissionPeriodTotals> byYear, {
    int count = 5,
  }) {
    final years = byYear.keys.toList()..sort();
    final slice =
        years.length <= count ? years : years.sublist(years.length - count);
    return [
      for (final year in slice)
        (year: year, totals: byYear[year] ?? CommissionPeriodTotals.zero),
    ];
  }

  static List<QueryDocumentSnapshot<Map<String, dynamic>>> docsInMonth(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    CommissionMonthKey key,
  ) {
    return docs.where((doc) {
      final date = CommissionCollectionsHelper.entryDate(doc.data());
      if (date == null) return false;
      return CommissionMonthKey.fromDate(date) == key;
    }).toList();
  }

  static List<QueryDocumentSnapshot<Map<String, dynamic>>> docsInYear(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int year,
  ) {
    return docs.where((doc) {
      final date = CommissionCollectionsHelper.entryDate(doc.data());
      if (date == null) return false;
      return date.year == year;
    }).toList();
  }

  static List<CommissionPaymentTypeTotals> paymentTypesInMonth(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    CommissionMonthKey key,
  ) =>
      CommissionCollectionsHelper.totalsByPaymentType(docsInMonth(docs, key));

  static List<CommissionPaymentTypeTotals> paymentTypesInYear(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int year,
  ) =>
      CommissionCollectionsHelper.totalsByPaymentType(docsInYear(docs, year));
}
