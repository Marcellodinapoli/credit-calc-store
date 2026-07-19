import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connessione WebSocket Realtime OpenAI GA (senza header Beta).
WebSocketChannel connectOpenAiRealtimeWs({
  required Uri uri,
  required String ephemeralToken,
}) {
  return IOWebSocketChannel.connect(
    uri,
    headers: <String, dynamic>{
      HttpHeaders.authorizationHeader: 'Bearer $ephemeralToken',
    },
  );
}
