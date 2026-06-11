import '../models/field_visit.dart';
import 'itinerary_calendar_download.dart';

abstract final class ItineraryCalendarExport {
  static String buildIcs(
    List<FieldVisit> visits, {
    String calendarName = 'Itinerario CreditCalc',
  }) {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//CreditCore//Itinerario//IT')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH')
      ..writeln('X-WR-CALNAME:${_escape(calendarName)}');

    for (final visit in visits) {
      if (visit.status == FieldVisitStatus.cancelled) continue;
      buffer
        ..writeln('BEGIN:VEVENT')
        ..writeln('UID:${visit.id}@creditcore.it')
        ..writeln('DTSTAMP:${_formatUtc(DateTime.now().toUtc())}')
        ..writeln(
          'DTSTART:${_formatUtc(visit.scheduledAt.toUtc())}',
        )
        ..writeln(
          'DTEND:${_formatUtc(visit.scheduledAt.toUtc().add(const Duration(hours: 1)))}',
        )
        ..writeln('SUMMARY:${_escape(_visitTitle(visit))}');
      if (visit.address.trim().isNotEmpty) {
        buffer.writeln('LOCATION:${_escape(visit.address.trim())}');
      }
      final details = _visitDetails(visit);
      if (details.isNotEmpty) {
        buffer.writeln('DESCRIPTION:${_escape(details)}');
      }
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static Uri googleCalendarUrlForVisit(FieldVisit visit) {
    final start = visit.scheduledAt.toUtc();
    final end = start.add(const Duration(hours: 1));
    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': _visitTitle(visit),
      'dates': '${_formatUtc(start)}/${_formatUtc(end)}',
      if (visit.address.trim().isNotEmpty) 'location': visit.address.trim(),
      if (_visitDetails(visit).isNotEmpty) 'details': _visitDetails(visit),
    });
  }

  static Future<void> downloadDayIcs({
    required List<FieldVisit> visits,
    required DateTime day,
  }) {
    final active = visits
        .where((v) => v.status != FieldVisitStatus.cancelled)
        .toList();
    final d = day.day.toString().padLeft(2, '0');
    final m = day.month.toString().padLeft(2, '0');
    return downloadCalendarFile(
      filename: 'itinerario-$d$m${day.year}.ics',
      content: buildIcs(active),
    );
  }

  static String _visitTitle(FieldVisit visit) {
    final name = visit.companyName.trim();
    return name.isEmpty ? 'Visita' : name;
  }

  static String _visitDetails(FieldVisit visit) {
    final parts = <String>[
      if (visit.creditorName != null && visit.creditorName!.trim().isNotEmpty)
        'Creditore: ${visit.creditorName!.trim()}',
      if (visit.notes != null && visit.notes!.trim().isNotEmpty)
        visit.notes!.trim(),
      'Stato: ${fieldVisitStatusLabel(visit.status)}',
    ];
    return parts.join('\n');
  }

  static String _formatUtc(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}'
        'T${two(value.hour)}${two(value.minute)}${two(value.second)}Z';
  }

  static String _escape(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', '\\n')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;');
  }
}
