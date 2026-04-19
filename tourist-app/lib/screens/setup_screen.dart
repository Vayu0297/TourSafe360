import 'package:flutter/material.dart';
import '../services/config.dart';
import '../services/api.dart';

class SetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SetupScreen({super.key, required this.onDone});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlCtrl = TextEditingController(text: 'http://');
  bool _loading = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    Config.getServerUrl().then((url) => _urlCtrl.text = url);
  }

  Future<void> _connect() async {
    setState(() { _loading = true; _status = 'Connecting...'; });
    await Config.setServerUrl(_urlCtrl.text);
    final ok = await ApiService.checkServer();
    setState(() {
      _loading = false;
      _status = ok ? '✅ Connected!' : '❌ Cannot connect. Check IP and port.';
    });
    if (ok) {
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onDone();
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
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🛡️', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                const Text('TourSafe360', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                const Text('AI Tourism Safety Platform', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Server Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                      const SizedBox(height: 6),
                      const Text('Enter your TourSafe360 backend URL', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _urlCtrl,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Server URL',
                          hintText: 'http://192.168.1.100:8000',
                          prefixIcon: const Icon(Icons.wifi, color: Color(0xFF6C63FF)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_status.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _status.contains('✅') ? const Color(0xFFecfdf5) : const Color(0xFFfef2f2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_status, style: TextStyle(
                            color: _status.contains('✅') ? const Color(0xFF059669) : const Color(0xFFef4444),
                            fontSize: 13, fontWeight: FontWeight.w600,
                          )),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _connect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _loading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text('Connect →', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
