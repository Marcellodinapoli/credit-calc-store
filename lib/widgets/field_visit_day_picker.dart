import 'package:flutter/material.dart';

import '../models/field_visit.dart';
import '../services/field_visit_service.dart';

const _pickerHeaderBackground = Color(0xFF1565C0);
const _pickerHeaderForeground = Colors.white;
const _pickerActionColor = Color(0xFF1565C0);
const _dayCellHeight = 62.0;
const _calendarChromeHeight = 118.0;

int _monthGridRowCount(DateTime month, MaterialLocalizations localizations) {
  const calendar = GregorianCalendarDelegate();
  final daysInMonth =
      calendar.getDaysInMonth(month.year, month.month);
  final firstDayOffset = calendar.firstDayOffset(
    month.year,
    month.month,
    localizations,
  );
  return ((firstDayOffset + daysInMonth) / 7).ceil();
}

double _calendarPanelHeight(
  DateTime month,
  MaterialLocalizations localizations,
) {
  return _calendarChromeHeight +
      _monthGridRowCount(month, localizations) * _dayCellHeight +
      12;
}

Future<DateTime?> showFieldVisitDayPicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final calendar = const GregorianCalendarDelegate();
  return showDialog<DateTime>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => FieldVisitDayPickerDialog(
      initialDate: calendar.dateOnly(initialDate),
      firstDate: calendar.dateOnly(firstDate ?? DateTime(2020)),
      lastDate: calendar.dateOnly(lastDate ?? DateTime(2100)),
    ),
  );
}

Future<DateTime?> pickFieldVisitDateAndTime(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final date = await showFieldVisitDayPicker(
    context,
    initialDate: initial,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    useRootNavigator: false,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;

  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
}

class FieldVisitDayPickerDialog extends StatefulWidget {
  const FieldVisitDayPickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<FieldVisitDayPickerDialog> createState() =>
      _FieldVisitDayPickerDialogState();
}

class _FieldVisitDayPickerDialogState extends State<FieldVisitDayPickerDialog> {
  static const _calendar = GregorianCalendarDelegate();

  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  bool _isSelectable(DateTime day) =>
      !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);

  void _shiftMonth(int delta) {
    setState(() {
      _displayedMonth = _calendar.addMonthsToMonthDate(_displayedMonth, delta);
    });
  }

  void _selectDay(DateTime day) {
    if (!_isSelectable(day)) return;
    setState(() => _selectedDate = day);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final wide = screenWidth >= 520;
    const dialogWidth = 560.0;
    final panelHeight = _calendarPanelHeight(_displayedMonth, localizations);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: StreamBuilder<List<FieldVisit>>(
        stream: FieldVisitService.watchAllForUser(),
        builder: (context, snapshot) {
          final counts = FieldVisitService.visitCountsByDayId(
            snapshot.data ?? const [],
          );
          final loading =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

          final calendar = _CalendarPanel(
            displayedMonth: _displayedMonth,
            selectedDate: _selectedDate,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            visitCounts: counts,
            loading: loading,
            onMonthChanged: _shiftMonth,
            onDaySelected: _selectDay,
          );

          return SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: panelHeight,
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HeaderPanel(
                              selectedDate: _selectedDate,
                              calendarDelegate: _calendar,
                            ),
                            Expanded(child: calendar),
                          ],
                        )
                      : calendar,
                ),
                Material(
                  color: colorScheme.surface,
                  elevation: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: _pickerActionColor,
                              ),
                              child: const Text(
                                'Annulla',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => Navigator.pop(
                                context,
                                _selectedDate,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _pickerActionColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text(
                                'OK',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({
    required this.selectedDate,
    required this.calendarDelegate,
  });

  final DateTime selectedDate;
  final CalendarDelegate<DateTime> calendarDelegate;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 168,
      color: _pickerHeaderBackground,
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seleziona data',
            style: textTheme.labelLarge?.copyWith(
              color: _pickerHeaderForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            localizations.narrowWeekdays[selectedDate.weekday % 7],
            style: textTheme.titleMedium?.copyWith(
              color: _pickerHeaderForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            localizations.formatDecimal(selectedDate.day),
            style: textTheme.displayMedium?.copyWith(
              color: _pickerHeaderForeground,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            calendarDelegate.formatShortMonthDay(selectedDate, localizations),
            style: textTheme.titleMedium?.copyWith(
              color: _pickerHeaderForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.displayedMonth,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
    required this.visitCounts,
    required this.loading,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  final DateTime displayedMonth;
  final DateTime selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Map<String, int> visitCounts;
  final bool loading;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  static const _calendar = GregorianCalendarDelegate();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final localizations = MaterialLocalizations.of(context);
    final today = _calendar.dateOnly(_calendar.now());

    final daysInMonth = _calendar.getDaysInMonth(
      displayedMonth.year,
      displayedMonth.month,
    );
    final firstDayOffset = _calendar.firstDayOffset(
      displayedMonth.year,
      displayedMonth.month,
      localizations,
    );

    final weekdayLabels = <String>[
      for (var i = 0; i < 7; i++)
        localizations.narrowWeekdays[
            (localizations.firstDayOfWeekIndex + i) % 7],
    ];

    final canGoPrev = !DateTime(displayedMonth.year, displayedMonth.month, 1)
        .isBefore(DateTime(firstDate.year, firstDate.month, 1));
    final canGoNext = !DateTime(displayedMonth.year, displayedMonth.month, 1)
        .isAfter(DateTime(lastDate.year, lastDate.month, 1));
    final gridRows = _monthGridRowCount(displayedMonth, localizations);
    final gridHeight = gridRows * _dayCellHeight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: canGoPrev ? () => onMonthChanged(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _calendar.formatMonthYear(displayedMonth, localizations),
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: canGoNext ? () => onMonthChanged(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Text(
            'Il numero su ogni giorno indica quante visite hai in agenda.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final label in weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: gridHeight,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: _dayCellHeight,
                ),
                itemCount: firstDayOffset + daysInMonth,
                itemBuilder: (context, index) {
                if (index < firstDayOffset) return const SizedBox.shrink();

                final day = index - firstDayOffset + 1;
                final date = _calendar.getDay(
                  displayedMonth.year,
                  displayedMonth.month,
                  day,
                );
                final count = visitCounts[FieldVisitService.visitDayKeyId(date)] ?? 0;
                final selected = _calendar.isSameDay(date, selectedDate);
                final isToday = _calendar.isSameDay(date, today);
                final enabled =
                    !date.isBefore(firstDate) && !date.isAfter(lastDate);

                return _DayCell(
                  day: day,
                  count: count,
                  selected: selected,
                  isToday: isToday,
                  enabled: enabled,
                  onTap: () => onDaySelected(date),
                );
              },
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.selected,
    required this.isToday,
    required this.enabled,
    required this.onTap,
  });

  final int day;
  final int count;
  final bool selected;
  final bool isToday;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final dayColor = !enabled
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : selected
            ? colorScheme.onPrimary
            : isToday
                ? colorScheme.primary
                : colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          height: _dayCellHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: selected
                    ? BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      )
                    : isToday
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.primary),
                          )
                        : null,
                child: Text(
                  '$day',
                  style: textTheme.bodyMedium?.copyWith(
                    color: dayColor,
                    fontWeight: isToday || selected ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (count > 0)
                Positioned(
                  top: 4,
                  right: 2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? colorScheme.onPrimary : colorScheme.primary,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: selected ? colorScheme.primary : colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: textTheme.labelSmall?.copyWith(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
