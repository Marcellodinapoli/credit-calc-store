/// Aggiunge [months] mantenendo il giorno di scadenza (es. sempre il 31, o il 30 se assente).
DateTime addMonthsSameCalendarDay(DateTime date, int months) {
  final targetMonth = date.month + months;
  final year = date.year + (targetMonth - 1) ~/ 12;
  final month = ((targetMonth - 1) % 12) + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = date.day <= lastDay ? date.day : lastDay;
  return DateTime(year, month, day);
}
