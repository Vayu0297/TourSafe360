import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/tourists_tab.dart';
import 'tabs/sos_tab.dart';
import 'tabs/chat_tab.dart';
import 'tabs/log_tab.dart';
import 'tabs/settings_tab.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String token;
  const HomeScreen({super.key, required this.token});
  @override State<HomeScreen> createState() => _HS();
}
class _HS extends State<HomeScreen> {
  int _tab = 0;
  List<PatrolTourist> tourists = [];
  List<SOSAlert> alerts = [];
  List<ChatMessage> msgs = [];
  String name = 'Officer', badge = 'PL-0000', zone = 'NE India';
  bool connected = false;
  int unSOS = 0, unChat = 0;
  Timer? _t;

  @override void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    setState(() { name = p.getString('officer_name') ?? 'Officer'; badge = p.getString('officer_badge') ?? 'PL-0000'; zone = p.getString('officer_zone') ?? 'NE India'; });
    await _load();
    _sock(); _track();
    _t = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  Future<void> _load() async {
    final r = await Future.wait([ApiService.getTourists(widget.token), ApiService.getSOS(widget.token)]);
    final na = (r[1] as List).map((e) => SOSAlert.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final prev = alerts.where((a) => a.status == 'active').length;
    final now = na.where((a) => a.status == 'active').length;
    if (!mounted) return;
    setState(() {
      tourists = (r[0] as List).map((e) => PatrolTourist.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      alerts = na;
      if (now > prev && _tab != 3) unSOS += now - prev;
    });
    if (now > prev) {
      final n = na.firstWhere((a) => a.status == 'active');
      NotificationService.showSOS('SOS: ${n.touristName}', n.type);
      try { await Vibration.vibrate(pattern: [0, 300, 150, 300, 150, 600]); } catch (_) {}
    }
  }

  void _sock() {
    SocketService.onConnect = (c) => setState(() => connected = c);
    SocketService.onSOS = (d) {
      final a = SOSAlert.fromJson(d); setState(() { alerts = [a, ...alerts.where((x) => x.id != a.id)]; if (_tab != 3) unSOS++; });
      NotificationService.showSOS('SOS: ${a.touristName}', a.type);
      try { Vibration.vibrate(pattern: [0, 500, 200, 500]); } catch (_) {}
    };
    SocketService.onTouristUpdate = (d) { final t = PatrolTourist.fromJson(d); setState(() => tourists = tourists.map((x) => x.id == t.id ? t : x).toList()); };
    SocketService.onMessage = (d) {
      final m = ChatMessage(id: '${DateTime.now().millisecondsSinceEpoch}', sender: '${d['from_name'] ?? 'Unknown'}', senderType: '${d['from_type'] ?? 'system'}', text: '${d['text'] ?? ''}', time: DateTime.now(), isMe: false);
      setState(() { msgs = [...msgs, m]; if (_tab != 4) unChat++; });
    };
    SocketService.connect(widget.token);
  }

  void _track() async {
    if (!await LocationService.requestPerm()) return;
    LocationService.startTracking((pos) { SocketService.sendLoc(pos.latitude, pos.longitude); ApiService.updateLoc(widget.token, pos.latitude, pos.longitude); });
  }

  void _logout() async {
    LocationService.stop(); SocketService.disconnect(); _t?.cancel();
    await (await SharedPreferences.getInstance()).remove('patrol_token');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _go(int i) => setState(() { _tab = i; if (i==3) unSOS=0; if (i==4) unChat=0; });

  void _sendMsg(String toId, String toType, String text) {
    final m = ChatMessage(id: '${DateTime.now().millisecondsSinceEpoch}', sender: name, senderType: 'patrol', text: text, time: DateTime.now(), isMe: true);
    setState(() => msgs = [...msgs, m]);
    SocketService.sendMsg(toId, toType, text); ApiService.sendMsg(widget.token, toId, toType, text);
  }

  void _resp(String id) async {
    await ApiService.respondSOS(widget.token, id);
    setState(() => alerts = alerts.map((a) => a.id == id ? a.copyWith(status: 'responding', responder: badge) : a).toList());
  }
  void _resolve(String id) async {
    await ApiService.resolveSOS(widget.token, id);
    setState(() => alerts = alerts.map((a) => a.id == id ? a.copyWith(status: 'resolved') : a).toList());
  }

  Widget _bw(int c, Widget w) => c == 0 ? w : Stack(clipBehavior: Clip.none, children: [w,
    Positioned(top: -4, right: -4, child: Container(width:16,height:16,
      decoration: const BoxDecoration(color: Color(0xFFFF3D3D), shape: BoxShape.circle),
      child: Center(child: Text(c>9?'9+':'$c', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))))]);

  @override
  Widget build(BuildContext context) {
    final aSOS = alerts.where((a) => a.status == 'active').length;
    final tabs = [
      DashboardTab(tourists: tourists, alerts: alerts, name: name, badge: badge, zone: zone, connected: connected, onNav: _go),
      MapTab(tourists: tourists, alerts: alerts),
      TouristsTab(tourists: tourists, onMsg: (_) => _go(4)),
      SOSTab(alerts: alerts, onRespond: _resp, onResolve: _resolve),
      ChatTab(msgs: msgs, tourists: tourists, onSend: _sendMsg),
      LogTab(token: widget.token),
      SettingsTab(name: name, badge: badge, zone: zone, token: widget.token, onLogout: _logout),
    ];
    const navItems = [
      (Icons.dashboard_rounded, 'Home'), (Icons.map_rounded, 'Map'),
      (Icons.people_rounded, 'Tourists'), (Icons.sos_rounded, 'SOS'),
      (Icons.chat_rounded, 'Chat'), (Icons.edit_note_rounded, 'Log'),
      (Icons.settings_rounded, 'More'),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF050C18),
      body: Column(children: [
        if (aSOS > 0) GestureDetector(onTap: () => _go(3),
          child: Container(color: const Color(0xCCFF3D3D), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SafeArea(bottom: false, child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20), const SizedBox(width: 8),
              Expanded(child: Text('⚠ $aSOS ACTIVE SOS — TAP TO RESPOND', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
              const Icon(Icons.chevron_right, color: Colors.white),
            ])))),
        Expanded(child: IndexedStack(index: _tab, children: tabs)),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Color(0xFF080F22), border: Border(top: BorderSide(color: Color(0x1F00B4FF)))),
        child: SafeArea(child: Row(children: List.generate(navItems.length, (i) {
          final on = _tab == i;
          final (icon, label) = navItems[i];
          return Expanded(child: GestureDetector(onTap: () => _go(i),
            child: Container(color: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _bw(i==3?unSOS:i==4?unChat:0, Icon(icon, color: on?const Color(0xFF00B4FF):const Color(0xFF7B8AB3), size: 22)),
                const SizedBox(height: 3),
                Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: on?const Color(0xFF00B4FF):const Color(0xFF7B8AB3))),
              ]))));
        }))),
      ),
    );
  }
  @override void dispose() { _t?.cancel(); LocationService.stop(); super.dispose(); }
}
