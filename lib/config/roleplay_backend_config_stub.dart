String resolveRealtimeWebSocketUrl({
  required bool kIsWeb,
  required String localWsHost,
  required int localRealtimeWsPort,
  required String secureHost,
}) {
  return 'wss://$secureHost/realtime-ws';
}
