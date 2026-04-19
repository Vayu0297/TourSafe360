import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Tourist';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name') ?? 'Tourist';
      _email = prefs.getString('user_email') ?? '';
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Logout', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (confirm == true) {
      await ApiService.clearToken();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200, pinned: true,
            backgroundColor: const Color(0xFF6C63FF),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFFa855f7)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
                    child: Center(child: Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'T',
                      style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w800))),
                  ),
                  const SizedBox(height: 12),
                  Text(_name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(_email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Text('🛡️ AI Protected Tourist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ])),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _section('AI Safety Features', [
                _feature('🏔️', 'Fall Detection', 'Active', Colors.green),
                _feature('🤖', 'Mistral-7B Triage', 'Ready', const Color(0xFF6C63FF)),
                _feature('🌏', '20+ Languages', 'Enabled', Colors.blue),
                _feature('📡', 'Real-time Tracking', 'Active', Colors.green),
                _feature('🚑', 'Ambulance Alert', 'Ready', Colors.red),
              ]),
              const SizedBox(height: 16),
              _section('About TourSafe360', [
                _info('Version', 'v2.0.0 Flutter'),
                _info('AI Engine', 'Mistral-7B + Llama3.2'),
                _info('Backend', 'FastAPI + LangGraph'),
                _info('Models', '3 custom PyTorch models'),
              ]),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _logout,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfef2f2), borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFfecaca), width: 1.5),
                  ),
                  child: const Center(child: Text('Logout', style: TextStyle(color: Color(0xFFef4444), fontSize: 16, fontWeight: FontWeight.w700))),
                ),
              ),
              const SizedBox(height: 80),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.08), blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _feature(String icon, String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF444444)))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value, style: const TextStyle(color: Color(0xFF333333), fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
