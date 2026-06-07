import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart' show AppCardTheme;
import 'package:flutter/material.dart';

import 'commission_collections_shared.dart';
import 'commission_statistics.dart';

enum _StatsView { monthly, yearly }

class CommissionStatisticsSection extends StatefulWidget {
  const CommissionStatisticsSection({
    super.key,
    required this.docs,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  @override
  State<CommissionStatisticsSection> createState() =>
      _CommissionStatisticsSectionState();
}

class _CommissionStatisticsSectionState
    extends State<CommissionStatisticsSection> {
  static const _primaryBlue = Color(0xFF0A66C2);

  static const _paymentTypeColors = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
    Color(0xFFAD1457),
    Color(0xFF4527A0),
  ];

  _StatsView _view = _StatsView.monthly;

  @override
  Widget build(BuildContext context) {
    if (widget.docs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 12),
              Text(
                'Registra i primi incassi per visualizzare confronti mensili '
                'e annuali.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 16),
            SegmentedButton<_StatsView>(
              segments: const [
                ButtonSegment(
                  value: _StatsView.monthly,
                  label: Text('Confronto mensile'),
                  icon: Icon(Icons.calendar_month_outlined, size: 18),
                ),
                ButtonSegment(
                  value: _StatsView.yearly,
                  label: Text('Confronto annuale'),
                  icon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                setState(() => _view = selection.first);
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(height: 20),
            if (_view == _StatsView.monthly)
              _monthlyContent(widget.docs)
            else
              _yearlyContent(widget.docs),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.insights_outlined, color: _primaryBlue),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statistiche e confronti',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Andamento provvigioni, incassi e pratiche rispetto al periodo precedente.',
                style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthlyContent(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final byMonth = CommissionStatisticsHelper.totalsByMonth(docs);
    final now = CommissionMonthKey.fromDate(DateTime.now());
    final previous = CommissionStatisticsHelper.previousMonth(now);

    final current = byMonth[now] ?? CommissionPeriodTotals.zero;
    final prior = byMonth[previous] ?? CommissionPeriodTotals.zero;

    final yearMonths =
        CommissionStatisticsHelper.monthsInYearWithIncassi(byMonth);
    final currentMonthIndex = yearMonths.indexWhere((e) => e.key == now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _comparisonTable(
          currentLabel: CommissionCollectionsHelper.monthLabel(now),
          previousLabel: CommissionCollectionsHelper.monthLabel(previous),
          current: current,
          previous: prior,
        ),
        if (yearMonths.isNotEmpty) ...[
          const SizedBox(height: 20),
          _trendTitle(
            'Andamento ${now.year} (provvigioni)',
          ),
          const SizedBox(height: 12),
          _barTrend(
            items: [
              for (final entry in yearMonths)
                (
                  label: CommissionStatisticsHelper.shortMonthLabel(
                    entry.key,
                    omitYear: true,
                  ),
                  value: entry.totals.commission,
                ),
            ],
            highlightIndex:
                currentMonthIndex >= 0 ? currentMonthIndex : null,
          ),
          _periodDetailsList(
            title: 'Dettaglio per mese',
            entries: [
              for (final entry in yearMonths.reversed)
                _PeriodDetailEntry(
                  label: CommissionCollectionsHelper.monthLabel(entry.key),
                  totals: entry.totals,
                  paymentTypes:
                      CommissionStatisticsHelper.paymentTypesInMonth(
                    docs,
                    entry.key,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _yearlyContent(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final byYear = CommissionStatisticsHelper.totalsByYear(docs);
    final currentYear = DateTime.now().year;
    final previousYear = currentYear - 1;

    final current = byYear[currentYear] ?? CommissionPeriodTotals.zero;
    final prior = byYear[previousYear] ?? CommissionPeriodTotals.zero;

    final recent = CommissionStatisticsHelper.recentYears(byYear);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _comparisonTable(
          currentLabel: '$currentYear',
          previousLabel: '$previousYear',
          current: current,
          previous: prior,
        ),
        const SizedBox(height: 20),
        _trendTitle('Andamento anni (provvigioni)'),
        const SizedBox(height: 12),
        _barTrend(
          items: [
            for (final entry in recent)
              (label: '${entry.year}', value: entry.totals.commission),
          ],
          highlightIndex: recent.isEmpty
              ? null
              : () {
                  final i =
                      recent.indexWhere((e) => e.year == currentYear);
                  return i >= 0 ? i : recent.length - 1;
                }(),
        ),
        _periodDetailsList(
          title: 'Dettaglio per anno',
          entries: [
            for (final entry in recent.reversed)
              _PeriodDetailEntry(
                label: '${entry.year}',
                totals: entry.totals,
                paymentTypes: CommissionStatisticsHelper.paymentTypesInYear(
                  docs,
                  entry.year,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _trendTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _comparisonTable({
    required String currentLabel,
    required String previousLabel,
    required CommissionPeriodTotals current,
    required CommissionPeriodTotals previous,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppCardTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Indicatore',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    currentLabel,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    previousLabel,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
          const Divider(height: 1),
          _comparisonRow(
            'Provvigioni',
            current.commission,
            previous.commission,
            highlight: true,
          ),
          _comparisonRow(
            'Incassato',
            current.collected,
            previous.collected,
          ),
          _comparisonRow(
            'Pratiche',
            current.practiceCount.toDouble(),
            previous.practiceCount.toDouble(),
            isCount: true,
          ),
        ],
      ),
    );
  }

  Widget _comparisonRow(
    String label,
    double current,
    double previous, {
    bool highlight = false,
    bool isCount = false,
  }) {
    final deltaPercent =
        isCount ? null : commissionPercentChange(current, previous);
    final deltaCount =
        isCount ? current.round() - previous.round() : null;
    final currentText = isCount
        ? current.round().toString()
        : CommissionCollectionsHelper.formatEuro(current);
    final previousText = isCount
        ? previous.round().toString()
        : CommissionCollectionsHelper.formatEuro(previous);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                color: highlight ? _primaryBlue : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              currentText,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: highlight ? _primaryBlue : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              previousText,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          SizedBox(
            width: 56,
            child: isCount
                ? _deltaCountChip(deltaCount ?? 0)
                : _deltaChip(deltaPercent),
          ),
        ],
      ),
    );
  }

  Widget _deltaChip(double? percent) {
    if (percent == null) {
      return Align(
        alignment: Alignment.centerRight,
        child: Text(
          '—',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      );
    }

    final positive = percent > 0.05;
    final negative = percent < -0.05;
    final neutral = !positive && !negative;

    final color = neutral
        ? Colors.green.shade700
        : positive
            ? Colors.green.shade700
            : Colors.red.shade700;

    final prefix = positive ? '+' : '';
    final text = '$prefix${percent.toStringAsFixed(1)}%';

    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: color,
        ),
      ),
    );
  }

  Widget _deltaCountChip(int delta) {
    final color = delta == 0
        ? Colors.green.shade700
        : delta > 0
            ? Colors.green.shade700
            : Colors.red.shade700;
    final text = delta > 0 ? '+$delta' : '$delta';

    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: color,
        ),
      ),
    );
  }

  Widget _periodDetailsList({
    required String title,
    required List<_PeriodDetailEntry> entries,
  }) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        _trendTitle(title),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppCardTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _periodDetailTile(entries[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodDetailTile(_PeriodDetailEntry entry) {
    final hasData = entry.totals.practiceCount > 0;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          entry.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            hasData
                ? 'Provvigioni ${CommissionCollectionsHelper.formatEuro(entry.totals.commission)}'
                    ' · Incassato ${CommissionCollectionsHelper.formatEuro(entry.totals.collected)}'
                    ' · ${entry.totals.practiceCount} pratiche'
                : 'Nessun incasso registrato',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
        children: [
          if (!hasData)
            Text(
              'Registra incassi in questo periodo per vedere le tipologie.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else ...[
            _periodSummaryRow(entry.totals),
            _paymentTypeLines(entry.paymentTypes),
          ],
        ],
      ),
    );
  }

  Widget _periodSummaryRow(CommissionPeriodTotals totals) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: _miniStat(
              'Provvigioni',
              CommissionCollectionsHelper.formatEuro(totals.commission),
              highlight: true,
            ),
          ),
          Expanded(
            child: _miniStat(
              'Incassato',
              CommissionCollectionsHelper.formatEuro(totals.collected),
            ),
          ),
          Expanded(
            child: _miniStat(
              'Pratiche',
              totals.practiceCount.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: highlight ? _primaryBlue : Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _paymentTypeColor(int index) =>
      _paymentTypeColors[index % _paymentTypeColors.length];

  Widget _paymentTypeLines(List<CommissionPaymentTypeTotals> byType) {
    if (byType.isEmpty) {
      return Text(
        'Nessuna tipologia di incasso in questo periodo.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipologie di incasso',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < byType.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '${byType[i].label}: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _paymentTypeColor(i),
                    ),
                  ),
                  TextSpan(
                    text:
                        'Incassato ${CommissionCollectionsHelper.formatEuro(byType[i].collected)} · ',
                  ),
                  TextSpan(
                    text:
                        'Provvigioni ${CommissionCollectionsHelper.formatEuro(byType[i].commission)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: ' · ${byType[i].practiceCount} pratiche',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _barTrend({
    required List<({String label, double value})> items,
    int? highlightIndex,
    bool highlightLast = false,
  }) {
    if (items.isEmpty) {
      return Text(
        'Dati insufficienti per il grafico.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );
    }

    final maxValue = items
        .map((e) => e.value)
        .fold(0.0, (a, b) => a > b ? a : b);
    const chartHeight = 100.0;
    final highlighted = highlightIndex ??
        (highlightLast ? items.length - 1 : -1);

    return SizedBox(
      height: chartHeight + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4, right: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      items[i].value > 0
                          ? CommissionCollectionsHelper.formatEuro(
                              items[i].value,
                            )
                          : '—',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: maxValue <= 0
                          ? 4
                          : (items[i].value / maxValue * chartHeight)
                              .clamp(4.0, chartHeight),
                      decoration: BoxDecoration(
                        color: i == highlighted
                            ? _primaryBlue
                            : _primaryBlue.withValues(alpha: 0.35),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      items[i].label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodDetailEntry {
  final String label;
  final CommissionPeriodTotals totals;
  final List<CommissionPaymentTypeTotals> paymentTypes;

  const _PeriodDetailEntry({
    required this.label,
    required this.totals,
    required this.paymentTypes,
  });
}
