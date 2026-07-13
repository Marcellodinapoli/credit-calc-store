// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

String resolveRealtimeWebSocketUrl({
  required bool kIsWeb,
  required String localWsHost,
  required int localRealtimeWsPort,
  required String secureHost,
}) {
  if (kIsWeb && html.window.location.protocol == 'https:') {
    return 'wss://$secureHost/realtime-ws';
  }
  if (kIsWeb) {
    return 'ws://$localWsHost:$localRealtimeWsPort';
  }
  return 'wss://$secureHost/realtime-ws';
}
