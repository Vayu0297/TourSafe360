import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _p = FlutterLocalNotificationsPlugin();
  static Future<void> init() async {
    const settings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));
    await _p.initialize(settings);
  }
  static Future<void> showSOS(String title, String body) async {
    const nd = NotificationDetails(
      android: AndroidNotificationDetails('sos_ch', 'SOS Alerts',
        importance: Importance.max, priority: Priority.high, enableVibration: true));
    await _p.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, nd);
  }
}
