import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

class SocketService {
  static IO.Socket? _s;
  static void Function(Map<String, dynamic>)? onSOS;
  static void Function(Map<String, dynamic>)? onTouristUpdate;
  static void Function(Map<String, dynamic>)? onMessage;
  static void Function(bool)? onConnect;

  static Future<void> connect(String token) async {
    final p = await SharedPreferences.getInstance();
    final base = p.getString('api_url') ?? 'http://192.168.1.100:8000';
    _s?.disconnect();
    _s = IO.io(base, IO.OptionBuilder().setTransports(['websocket', 'polling'])
      .setExtraHeaders({'Authorization': 'Bearer $token'}).enableAutoConnect().enableReconnection().build());
    _s!.onConnect((_) => onConnect?.call(true));
    _s!.onDisconnect((_) => onConnect?.call(false));
    _s!.on('sos_alert', (d) { if (d is Map) onSOS?.call(Map<String, dynamic>.from(d)); });
    _s!.on('tourist_update', (d) { if (d is Map) onTouristUpdate?.call(Map<String, dynamic>.from(d)); });
    _s!.on('message', (d) { if (d is Map) onMessage?.call(Map<String, dynamic>.from(d)); });
    _s!.on('patrol_message', (d) { if (d is Map) onMessage?.call(Map<String, dynamic>.from(d)); });
    _s!.connect();
  }
  static void sendLoc(double lat, double lng) => _s?.emit('patrol_location', {'latitude': lat, 'longitude': lng});
  static void sendMsg(String toId, String toType, String text) => _s?.emit('send_message', {'to_id': toId, 'to_type': toType, 'text': text});
  static void disconnect() => _s?.disconnect();
  static bool get ok => _s?.connected ?? false;
}
