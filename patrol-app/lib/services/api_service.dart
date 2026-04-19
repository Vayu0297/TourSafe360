import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String API_BASE = 'http://10.90.88.240:8000';

class PatrolApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('patrol_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('patrol_token', token);
  }

  static Future<void> saveOfficer(Map<String,dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('officer_name', data['name'] ?? 'Officer');
    await prefs.setString('officer_id', data['id'] ?? '');
    await prefs.setString('officer_badge', data['badge'] ?? 'PL-0000');
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
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getTourists() async {
    final h = await authHeaders();
    final res = await http.get(Uri.parse('$API_BASE/api/tourists/active'), headers: h)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getAllSOS() async {
    final h = await authHeaders();
    final res = await http.get(Uri.parse('$API_BASE/api/sos/all'), headers: h)
        .timeout(const Duration(seconds: 10));
    return jsonDecode(res.body);
  }

  static Future<Map<String,dynamic>> updateSOSStatus(
      String alertId, String status, String officerName) async {
    final h = await authHeaders();
    final res = await http.put(
      Uri.parse('$API_BASE/api/sos/$alertId/resolve'),
      headers: h,
      body: jsonEncode({'status': status, 'assigned_to': officerName}),
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getGeofences() async {
    final res = await http.get(Uri.parse('$API_BASE/api/geofence/'))
        .timeout(const Duration(seconds: 10));
    return jsonDecode(res.body);
  }

  static Future<void> updatePatrolLocation(
      double lat, double lng, String officerName) async {
    final h = await authHeaders();
    await http.post(
      Uri.parse('$API_BASE/api/tourists/location'),
      headers: h,
      body: jsonEncode({
        'latitude': lat, 'longitude': lng,
        'location_name': 'Officer $officerName patrol location'
      }),
    ).timeout(const Duration(seconds: 5));
  }

  static Future<Map<String,dynamic>> submitPatrolReport(
      Map<String,dynamic> report) async {
    final h = await authHeaders();
    final res = await http.post(
      Uri.parse('$API_BASE/api/health/submit'),
      headers: h,
      body: jsonEncode(report),
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(res.body);
  }
}
