import 'package:web_socket_channel/web_socket_channel.dart';

/// Su web i WebSocket non supportano header Authorization.
WebSocketChannel connectOpenAiRealtimeWs({
  required Uri uri,
  required String ephemeralToken,
}) {
  throw UnsupportedError(
    'Roleplay Realtime su web richiede un client con header Authorization. '
    'Usa l\'app Android/iOS/desktop.',
  );
}
