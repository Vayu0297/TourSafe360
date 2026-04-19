import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String API_BASE = 'http://10.90.88.240:8000';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<Map<String,String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String,dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$API_BASE/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String,dynamic>> register(Map<String,dynamic> data) async {
    final res = await http.post(
      Uri.parse('$API_BASE/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<dynamic> updateLocation(double lat, double lng, String name) async {
    final headers = await authHeaders();
    final res = await http.put(
      Uri.parse('$API_BASE/api/tourists/location'),
      headers: headers,
      body: jsonEncode({'latitude': lat, 'longitude': lng, 'location_name': name}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String,dynamic>> triggerSOS(String type, double lat, double lng, String message) async {
    final headers = await authHeaders();
    final res = await http.post(
      Uri.parse('$API_BASE/api/sos/trigger'),
      headers: headers,
      body: jsonEncode({
        'alert_type': type, 'latitude': lat, 'longitude': lng,
        'location_name': '$lat, $lng', 'message': message,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String,dynamic>> chat(String message, String language) async {
    final res = await http.post(
      Uri.parse('$API_BASE/api/agents/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'language': language}),
    ).timeout(const Duration(seconds: 60));
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getZones() async {
    final res = await http.get(Uri.parse('$API_BASE/api/geofence/'));
    return jsonDecode(res.body);
  }

  static Future<dynamic> submitHealth(Map<String,dynamic> data) async {
    final headers = await authHeaders();
    final res = await http.post(
      Uri.parse('$API_BASE/api/health/submit'),
      headers: headers,
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }
}
