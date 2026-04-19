import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _aadhaar = TextEditingController();
  final _password = TextEditingController();
  final _blood = TextEditingController();
  final _emergency = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _register() async {
    if (_name.text.isEmpty || _email.text.isEmpty || _phone.text.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Please fill all required fields');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await ApiService.register({
        'name': _name.text, 'email': _email.text, 'phone': _phone.text,
        'password': _password.text, 'aadhaar_number': _aadhaar.text,
        'blood_group': _blood.text, 'emergency_contact': _emergency.text,
      });
      if (res['token'] != null) {
        await ApiService.saveToken(res['token']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _name.text);
        await prefs.setString('user_email', _email.text);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
      } else {
        setState(() => _error = res['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      setState(() => _error = 'Connection error');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF6C63FF), Color(0xFFa855f7)]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 20),
              const Text('🛡️', style: TextStyle(fontSize: 48)),
              const Text('Register', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
              const Text('Indian Tourist Registration', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  _field(_name, 'Full Name *', false),
                  _field(_email, 'Email *', false),
                  _field(_phone, 'Phone *', false),
                  _field(_aadhaar, 'Aadhaar Number', false),
                  _field(_password, 'Password *', true),
                  _field(_blood, 'Blood Group', false),
                  _field(_emergency, 'Emergency Contact', false),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_loading ? 'Registering...' : 'Register →',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_error, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already registered? Login', style: TextStyle(color: Color(0xFF6C63FF))),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, bool obscure) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl, obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint, filled: true, fillColor: const Color(0xFFf8f0ff),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFe8d5ff), width: 1.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFe8d5ff), width: 1.5)),
        ),
      ),
    );
  }
}
