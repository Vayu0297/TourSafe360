import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'main_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  bool _showOtp = false;
  String _otpMethod = 'email';
  String _error = '';

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter email and password');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await ApiService.login(_emailCtrl.text, _passCtrl.text);
      if (res['token'] != null) {
        await ApiService.saveToken(res['token']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', res['tourist']?['name'] ?? 'Tourist');
        await prefs.setString('user_email', res['tourist']?['email'] ?? '');
        if (mounted) Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const MainScreen()));
      } else {
        setState(() => _error = res['detail'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _error = 'Connection error. Check your network.');
    }
    setState(() => _loading = false);
  }

  void _requestOtp() {
    if (_emailCtrl.text.isEmpty) {
      setState(() => _error = 'Enter your email first');
      return;
    }
    setState(() { _showOtp = true; _error = '✅ OTP sent! Demo OTP: 123456'; });
  }

  void _verifyOtp() {
    if (_otpCtrl.text == '123456') {
      setState(() => _error = '');
      _login();
    } else {
      setState(() => _error = '❌ Wrong OTP. Demo OTP is: 123456');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF6C63FF), Color(0xFFa855f7)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 40),
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(child: Text('🛡️', style: TextStyle(fontSize: 48))),
              ),
              const SizedBox(height: 16),
              const Text('TourSafe360', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
              const Text('AI Safety Companion for NE India', style: TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_showOtp ? 'Enter OTP 🔐' : 'Welcome Back! 👋',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                  const SizedBox(height: 20),
                  if (!_showOtp) ...[
                    _buildInput(_emailCtrl, 'Email', Icons.email_outlined, false),
                    const SizedBox(height: 12),
                    _buildInput(_passCtrl, 'Password', Icons.lock_outlined, true),
                    const SizedBox(height: 20),
                    _buildPrimaryBtn(_loading ? 'Logging in...' : 'Login →', _loading ? null : _login),
                    const SizedBox(height: 16),
                    const Row(children: [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('OR', style: TextStyle(color: Colors.grey))),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Login with OTP', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _otpMethodBtn('📧', 'Email', 'email'),
                      const SizedBox(width: 8),
                      _otpMethodBtn('💬', 'WhatsApp', 'whatsapp'),
                      const SizedBox(width: 8),
                      _otpMethodBtn('📱', 'SMS', 'sms'),
                    ]),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _requestOtp,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(color: Color(0xFF6C63FF), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Send OTP via $_otpMethod',
                        style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w700)),
                    ),
                  ] else ...[
                    Text('OTP sent to ${_emailCtrl.text} via $_otpMethod',
                      style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 16),
                      decoration: InputDecoration(
                        hintText: '• • • • • •',
                        filled: true, fillColor: const Color(0xFFf8f0ff),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFe8d5ff), width: 2)),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPrimaryBtn('Verify OTP ✅', _verifyOtp),
                    TextButton(onPressed: () => setState(() { _showOtp = false; _error = ''; }),
                      child: const Text('← Back to login')),
                  ],
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _error.contains('✅') ? const Color(0xFFecfdf5) : const Color(0xFFfef2f2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error, style: TextStyle(fontSize: 12,
                        color: _error.contains('✅') ? const Color(0xFF059669) : const Color(0xFFef4444))),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('New tourist? Register here 🗺️',
                        style: TextStyle(color: Color(0xFF6C63FF))),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon, bool obscure) {
    return TextField(
      controller: ctrl, obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint, prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
        filled: true, fillColor: const Color(0xFFf8f0ff),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFe8d5ff), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFe8d5ff), width: 1.5)),
      ),
    );
  }

  Widget _buildPrimaryBtn(String label, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: const Color(0xFF6C63FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }

  Widget _otpMethodBtn(String emoji, String label, String method) {
    final active = _otpMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _otpMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF6C63FF) : const Color(0xFFf8f0ff),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? const Color(0xFF6C63FF) : const Color(0xFFe8d5ff), width: 1.5),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            Text(label, style: TextStyle(fontSize: 11,
              color: active ? Colors.white : Colors.grey, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
