import 'package:dio/dio.dart';
import 'config.dart';

class ApiService {
  static Dio? _dio;

  static Future<Dio> get dio async {
    final url = await Config.getServerUrl();
    final token = await Config.getToken();
    _dio = Dio(BaseOptions(
      baseUrl: '$url/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: token.isNotEmpty ? {'Authorization': 'Bearer $token'} : {},
    ));
    return _dio!;
  }

  // Auth
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final d = await dio;
    final res = await d.post('/auth/login', data: {'email': email, 'password': password});
    return res.data;
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final d = await dio;
    final res = await d.post('/auth/register', data: data);
    return res.data;
  }

  // Location
  static Future<void> updateLocation(double lat, double lng, String name) async {
    try {
      final d = await dio;
      await d.put('/tourists/location', data: {
        'latitude': lat, 'longitude': lng, 'location_name': name
      });
    } catch (e) {}
  }

  // SOS
  static Future<Map<String, dynamic>> triggerSOS({
    required String alertType, required double lat,
    required double lng, required String message,
  }) async {
    final d = await dio;
    final res = await d.post('/sos/trigger', data: {
      'alert_type': alertType, 'latitude': lat,
      'longitude': lng, 'message': message,
      'location_name': '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
    });
    return res.data;
  }

  // Health/Wearable
  static Future<Map<String, dynamic>?> submitWearable(Map<String, dynamic> data) async {
    try {
      final d = await dio;
      final res = await d.post('/health/wearable', data: data);
      return res.data;
    } catch (e) { return null; }
  }

  // Chat
  static Future<String> chat(String message, String language) async {
    final d = await dio;
    final res = await d.post('/agents/chat', data: {'message': message, 'language': language});
    return res.data['response'] ?? '';
  }

  // Zones
  static Future<List<dynamic>> getZones() async {
    try {
      final d = await dio;
      final res = await d.get('/geofence/');
      return res.data;
    } catch (e) { return []; }
  }

  // Health check
  static Future<bool> checkServer() async {
    try {
      final url = await Config.getServerUrl();
      final d = Dio();
      final res = await d.get('$url/health',
        options: Options(receiveTimeout: const Duration(seconds: 5)));
      return res.statusCode == 200;
    } catch (e) { return false; }
  }
}
