import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_urls.dart';
import '../storage/secure_storage.dart';
import 'dio_client.dart';

enum WsStatus { disconnected, connecting, connected }

class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  WsStatus _status = WsStatus.disconnected;

  final _statusController = StreamController<WsStatus>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<WsStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  WsStatus get status => _status;

  Future<void> connect() async {
    if (_status == WsStatus.connected || _status == WsStatus.connecting) return;
    _setStatus(WsStatus.connecting);
    try {
      final token = await SecureStorage().getAccessToken();
      final tenant = DioClient().tenantSchema ?? 'public';
      final uri = Uri.parse('${ApiUrls.wsBaseUrl}${ApiUrls.wsStock}?token=$token&tenant=$tenant');
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (data) {
          try {
            final payload = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController.add(payload);
          } catch (_) {}
        },
        onDone: () => _onDisconnected(),
        onError: (_) => _onDisconnected(),
      );
      _setStatus(WsStatus.connected);
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onDisconnected() {
    _setStatus(WsStatus.disconnected);
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void _setStatus(WsStatus status) {
    _status = status;
    _statusController.add(status);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setStatus(WsStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _messageController.close();
  }
}

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});
