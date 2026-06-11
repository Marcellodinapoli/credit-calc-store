import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadCalendarFile({
  required String filename,
  required String content,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await Clipboard.setData(ClipboardData(text: content));
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: content));
  }
}
