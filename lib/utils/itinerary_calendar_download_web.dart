// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<void> downloadCalendarFile({
  required String filename,
  required String content,
}) async {
  final bytes = html.Blob([content], 'text/calendar;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
