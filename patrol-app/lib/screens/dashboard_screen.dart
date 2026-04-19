import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:vibration/vibration.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final String officerName;
  final String badge;
  final Function(int) onSOSUpdate;
  const DashboardScreen({super.key, required this.officerName, required this.badge, required this.onSOSUpdate});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _tourists = [];
  List<dynamic> _sosList = [];
  List<dynamic> _geofences = [];
  bool _connected = false;
  IO.Socket? _socket;
  Timer? _timer;
  String _time = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
    _connectSocket();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _time = DateTime.now().toString().substring(11, 19));
    });
    Timer.periodic(const Duration(seconds: 15), (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    try {
      final t = await PatrolApiService.getTourists();
      final s = await PatrolApiService.getAllSOS();
      final g = await PatrolApiService.getGeofences();
      setState(() { _tourists = t; _sosList = s; _geofences = g; });
      widget.onSOSUpdate(s.where((a) => a['status'] == 'active').length);
    } catch (e) {}
  }

  void _connectSocket() {
    try {
      _socket = IO.io('http://10.90.88.240:8000', IO.OptionBuilder()
        .setTransports(['websocket']).enableReconnection().build());
      _socket!.onConnect((_) => setState(() => _connected = true));
      _socket!.onDisconnect((_) => setState(() => _connected = false));
      _socket!.on('sos_alert', (data) async {
        await Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
        _showSOSAlert(data);
        _fetchData();
      });
      _socket!.on('fall_detected', (data) async {
        await Vibration.vibrate(pattern: [0, 300, 100, 300]);
        _fetchData();
      });
    } catch (e) {}
  }

  void _showSOSAlert(dynamic data) {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF080f22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.red, width: 2),
      ),
      title: const Row(children: [
        Icon(Icons.warning_amber, color: Colors.red, size: 28),
        SizedBox(width: 8),
        Text('🚨 SOS ALERT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tourist: ${data['tourist_name'] ?? 'Unknown'}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Text('Type: ${data['alert_type'] ?? 'Emergency'}',
          style: const TextStyle(color: Colors.orange, fontSize: 14)),
        Text('Severity: ${data['severity']?.toString().toUpperCase() ?? 'HIGH'}',
          style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w700)),
        if (data['ai_triage'] != null) ...[
          const SizedBox(height: 8),
          Text('AI: ${data['ai_triage']['triage_summary'] ?? ''}',
            style: const TextStyle(color: Color(0xFF00b4ff), fontSize: 12)),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('DISMISS', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await PatrolApiService.updateSOSStatus(
              data['id'] ?? '', 'responding', widget.officerName);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('RESPONDING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ],
    ));
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSOS = _sosList.where((s) => s['status'] == 'active').length;
    final responding = _sosList.where((s) => s['status'] == 'responding').length;
    final resolved = _sosList.where((s) => s['status'] == 'resolved').length;

    return Scaffold(
      backgroundColor: const Color(0xFF050c18),
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF080f22),
              border: Border(bottom: BorderSide(color: Color(0xFF00b4ff), width: 0.5)),
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TOURSAFE360 PATROL', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900,
                  color: Color(0xFF00b4ff), letterSpacing: 2)),
                Text('Officer ${widget.officerName} · ${widget.badge}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
              const Spacer(),
              Text(_time, style: const TextStyle(
                color: Color(0xFF00e5cc), fontSize: 18,
                fontWeight: FontWeight.w700, fontFamily: 'monospace')),
              const SizedBox(width: 12),
              Container(
                width: 8, height: 8, decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _connected ? const Color(0xFF00e676) : Colors.red,
                  boxShadow: _connected ? [BoxShadow(color: const Color(0xFF00e676).withOpacity(0.5), blurRadius: 6)] : null,
                ),
              ),
            ]),
          ),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Active SOS banner
              if (activeSOS > 0) Container(
                width: double.infinity, padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 1.5),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 24),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'ACTIVE EMERGENCY — $activeSOS SOS ALERT${activeSOS > 1 ? "S" : ""} NEED ATTENTION',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 13),
                  )),
                ]),
              ),

              // Stat cards
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10, mainAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: [
                  _statCard('TOURISTS', '${_tourists.length}', Icons.people, const Color(0xFF00b4ff)),
                  _statCard('ACTIVE SOS', '$activeSOS', Icons.sos, Colors.red),
                  _statCard('RESPONDING', '$responding', Icons.local_police, Colors.orange),
                  _statCard('RESOLVED', '$resolved', Icons.check_circle, const Color(0xFF00e676)),
                ],
              ),
              const SizedBox(height: 16),

              // Recent SOS
              _sectionTitle('RECENT SOS ALERTS'),
              ..._sosList.take(5).map((s) => _sosCard(s)),

              const SizedBox(height: 16),

              // Geofence status
              _sectionTitle('GEOFENCE ZONES'),
              ..._geofences.take(4).map((g) => _geofenceCard(g)),

              const SizedBox(height: 16),

              // Tourists needing attention
              _sectionTitle('TOURISTS — LIVE STATUS'),
              ..._tourists.take(5).map((t) => _touristCard(t)),

              const SizedBox(height: 80),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF080f22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38, letterSpacing: 1)),
        ]),
      ]),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(title, style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: Color(0xFF00b4ff), letterSpacing: 1.5)),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 0.5, color: const Color(0xFF00b4ff).withOpacity(0.3))),
    ]),
  );

  Widget _sosCard(dynamic s) {
    final statusColor = s['status'] == 'active' ? Colors.red
        : s['status'] == 'responding' ? Colors.orange
        : const Color(0xFF00e676);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF080f22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 0.5),
      ),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(
          shape: BoxShape.circle, color: statusColor,
          boxShadow: [BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 4)],
        )),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['tourist_name'] ?? 'Unknown',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          Text('${s['alert_type'] ?? 'SOS'} · ${s['severity']?.toString().toUpperCase() ?? 'HIGH'}',
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.4)),
          ),
          child: Text((s['status'] ?? 'active').toUpperCase(),
            style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _geofenceCard(dynamic g) {
    final riskColor = (g['zone_type'] == 'red' || g['zone_type'] == 'restricted')
        ? Colors.red : g['zone_type'] == 'amber' ? Colors.orange : const Color(0xFF00e676);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF080f22),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: riskColor, width: 3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g['name'] ?? 'Zone', style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          Text('${g['state'] ?? ''} · ${((g['radius_meters'] ?? 5000) / 1000).toStringAsFixed(1)}km',
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: riskColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Text((g['zone_type'] ?? 'safe').toUpperCase(),
            style: TextStyle(color: riskColor, fontSize: 9, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _touristCard(dynamic t) {
    final hasLoc = t['current_lat'] != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF080f22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00b4ff).withOpacity(0.15), width: 0.5),
      ),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: const Color(0xFF0c1630),
          child: Text(t['name']?.toString().substring(0, 1) ?? 'T',
            style: const TextStyle(color: Color(0xFF00b4ff), fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['name'] ?? 'Unknown', style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(t['nationality'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ])),
        Icon(hasLoc ? Icons.location_on : Icons.location_off,
          color: hasLoc ? const Color(0xFF00e676) : Colors.white24, size: 16),
      ]),
    );
  }
}
