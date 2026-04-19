import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../services/api_service.dart';

class SOSScreen extends StatefulWidget {
  final String officerName;
  final Function(int) onSOSUpdate;
  const SOSScreen({super.key, required this.officerName, required this.onSOSUpdate});
  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  List<dynamic> _sosList = [];
  bool _loading = false;
  String _filter = 'all';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchSOS();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchSOS());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _fetchSOS() async {
    try {
      final s = await PatrolApiService.getAllSOS();
      setState(() => _sosList = s);
      widget.onSOSUpdate(s.where((a) => a['status'] == 'active').length);
    } catch (e) {}
  }

  Future<void> _updateStatus(String id, String status) async {
    setState(() => _loading = true);
    try {
      await PatrolApiService.updateSOSStatus(id, status, widget.officerName);
      if (status == 'responding') await Vibration.vibrate(duration: 200);
      await _fetchSOS();
    } catch (e) {}
    setState(() => _loading = false);
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active': return Colors.red;
      case 'responding': return Colors.orange;
      case 'resolved': return const Color(0xFF00e676);
      default: return Colors.grey;
    }
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'critical': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.yellow;
      default: return const Color(0xFF00e676);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all' ? _sosList
        : _sosList.where((s) => s['status'] == _filter).toList();
    final active = _sosList.where((s) => s['status'] == 'active').length;
    final responding = _sosList.where((s) => s['status'] == 'responding').length;
    final resolved = _sosList.where((s) => s['status'] == 'resolved' || s['status'] == 'false_alarm').length;

    return Scaffold(
      backgroundColor: const Color(0xFF050c18),
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF080f22),
          child: Row(children: [
            const Icon(Icons.sos, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            const Text('SOS ALERT MANAGEMENT', style: TextStyle(
              color: Colors.red, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
            const Spacer(),
            GestureDetector(onTap: _fetchSOS,
              child: const Icon(Icons.refresh, color: Colors.white38, size: 20)),
          ]),
        ),

        // Stats row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF080f22),
          child: Row(children: [
            _miniStat('ACTIVE', '$active', Colors.red),
            _miniStat('RESPONDING', '$responding', Colors.orange),
            _miniStat('RESOLVED', '$resolved', const Color(0xFF00e676)),
            _miniStat('TOTAL', '${_sosList.length}', const Color(0xFF00b4ff)),
          ]),
        ),

        // Filter tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            for (final f in ['all', 'active', 'responding', 'resolved'])
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _filter == f ? _statusColor(f == 'all' ? 'active' : f).withOpacity(0.2) : const Color(0xFF080f22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _filter == f ? _statusColor(f == 'all' ? 'active' : f) : Colors.white12),
                  ),
                  child: Text(f.toUpperCase(), textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                      color: _filter == f ? Colors.white : Colors.white38,
                      letterSpacing: 0.5)),
                ),
              )),
          ]),
        ),

        // SOS list
        Expanded(child: filtered.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF00e676), size: 48),
              const SizedBox(height: 12),
              Text('No $_filter alerts', style: const TextStyle(color: Colors.white38, fontSize: 14)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final s = filtered[i];
                final statusColor = _statusColor(s['status']);
                final severityColor = _severityColor(s['severity']);

                // Parse AI triage
                dynamic triage;
                try {
                  if (s['ai_triage'] is String) {
                    triage = null;
                  } else {
                    triage = s['ai_triage'];
                  }
                } catch (e) {}

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080f22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: statusColor.withOpacity(0.4), width: 1),
                  ),
                  child: Column(children: [
                    // Alert header
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Row(children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(
                          shape: BoxShape.circle, color: statusColor,
                          boxShadow: [BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 6)],
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['tourist_name'] ?? 'Unknown', style: const TextStyle(
                            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                          Text('${s['alert_type']?.toString().toUpperCase() ?? 'SOS'} · ${s['location_name'] ?? 'Unknown location'}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: severityColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: severityColor.withOpacity(0.5)),
                            ),
                            child: Text(s['severity']?.toString().toUpperCase() ?? 'HIGH',
                              style: TextStyle(color: severityColor, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(s['status']?.toString().toUpperCase() ?? 'ACTIVE',
                              style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      ]),
                    ),

                    // AI triage
                    if (triage != null) Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0c1630),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: const Color(0xFF00b4ff), width: 3)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('🤖 AI TRIAGE', style: TextStyle(
                            color: Color(0xFF00b4ff), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(triage['triage_summary']?.toString() ?? '',
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          if (triage['immediate_action'] != null) ...[
                            const SizedBox(height: 4),
                            Text('⚡ ${triage['immediate_action']}',
                              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                          if (triage['medical_needed'] == true)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red.withOpacity(0.5)),
                              ),
                              child: const Text('🚑 AMBULANCE REQUIRED',
                                style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                        ]),
                      ),
                    ),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        if (s['status'] == 'active') ...[
                          Expanded(child: _actionBtn('🚔 Responding', Colors.orange,
                            () => _updateStatus(s['id'], 'responding'))),
                          const SizedBox(width: 6),
                          Expanded(child: _actionBtn('⬜ False Alarm', Colors.grey,
                            () => _updateStatus(s['id'], 'false_alarm'))),
                        ],
                        if (s['status'] == 'responding')
                          Expanded(child: _actionBtn('✅ Mark Resolved', const Color(0xFF00e676),
                            () => _updateStatus(s['id'], 'resolved'))),
                        if (s['status'] == 'resolved' || s['status'] == 'false_alarm')
                          Expanded(child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00e676).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Case Closed', textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF00e676), fontSize: 12, fontWeight: FontWeight.w600)),
                          )),
                      ]),
                    ),
                  ]),
                );
              },
            )),
      ])),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, letterSpacing: 0.5)),
    ]),
  );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: _loading ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  );
}
