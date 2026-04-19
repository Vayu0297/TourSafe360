import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'ai@test.com');
  final _passCtrl = TextEditingController(text: 'Test@123');
  final _badgeCtrl = TextEditingController(text: 'PL-2847');
  bool _loading = false;
  String _error = '';

  Future<void> _login() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await PatrolApiService.login(_emailCtrl.text, _passCtrl.text);
      if (res['token'] != null) {
        await PatrolApiService.saveToken(res['token']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('officer_name', res['tourist']?['name'] ?? 'Officer');
        await prefs.setString('officer_badge', _badgeCtrl.text);
        await prefs.setString('officer_id', res['tourist']?['id'] ?? '');
        if (mounted) Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const MainScreen()));
      } else {
        setState(() => _error = res['detail'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _error = 'Connection error: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF050c18), Color(0xFF080f22), Color(0xFF0c1630)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              const SizedBox(height: 40),
              // Badge
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00b4ff), width: 2),
                  color: const Color(0xFF080f22),
                ),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('🛡️', style: TextStyle(fontSize: 40)),
                ]),
              ),
              const SizedBox(height: 20),
              const Text('TOURSAFE360', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900,
                color: Color(0xFF00b4ff), letterSpacing: 3)),
              const Text('PATROL COMMAND', style: TextStyle(
                fontSize: 12, color: Color(0xFF00e5cc), letterSpacing: 4)),
              const SizedBox(height: 8),
              const Text('Northeast India Tourism Safety', style: TextStyle(
                fontSize: 11, color: Colors.white38, letterSpacing: 1)),
              const SizedBox(height: 40),

              // Login form
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF080f22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00b4ff).withOpacity(0.2)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  _field(_emailCtrl, 'Officer Email', Icons.email_outlined),
                  const SizedBox(height: 12),
                  _field(_passCtrl, 'Password', Icons.lock_outlined, obscure: true),
                  const SizedBox(height: 12),
                  _field(_badgeCtrl, 'Badge Number', Icons.badge_outlined),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00b4ff),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('LOGIN TO PATROL', style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800,
                            fontSize: 14, letterSpacing: 1.5)),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_error, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ]),
              ),

              const SizedBox(height: 20),
              const Text('Authorized Personnel Only', style: TextStyle(
                color: Colors.white24, fontSize: 11, letterSpacing: 1)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: ctrl, obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: const Color(0xFF00b4ff), size: 20),
        filled: true, fillColor: const Color(0xFF0c1630),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00b4ff), width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: const Color(0xFF00b4ff).withOpacity(0.3), width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00b4ff), width: 1.5)),
      ),
    );
  }
}
