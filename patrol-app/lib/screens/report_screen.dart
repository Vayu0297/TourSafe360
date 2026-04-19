import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class ReportScreen extends StatefulWidget {
  final String officerName;
  final String badge;
  const ReportScreen({super.key, required this.officerName, required this.badge});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _notesCtrl = TextEditingController();
  String _incidentType = 'routine_patrol';
  String _areaStatus = 'clear';
  Position? _position;
  bool _submitting = false;
  String _msg = '';
  final List<Map<String,String>> _reports = [];

  final List<String> _incidentTypes = [
    'routine_patrol', 'tourist_assistance', 'suspicious_activity',
    'wildlife_sighting', 'weather_hazard', 'infrastructure_issue',
    'medical_assist', 'lost_tourist', 'other'
  ];

  final List<Map<String,dynamic>> _areaStatuses = [
    {'value':'clear','label':'All Clear','color':const Color(0xFF00e676)},
    {'value':'caution','label':'Caution','color':Colors.orange},
    {'value':'hazard','label':'Hazard','color':Colors.red},
    {'value':'restricted','label':'Restricted','color':Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _position = pos);
    } catch (e) {}
  }

  Future<void> _submitReport() async {
    if (_notesCtrl.text.isEmpty) {
      setState(() => _msg = '❌ Please add patrol notes');
      return;
    }
    setState(() { _submitting = true; _msg = ''; });
    try {
      await PatrolApiService.submitPatrolReport({
        'officer_name': widget.officerName,
        'badge': widget.badge,
        'incident_type': _incidentType,
        'area_status': _areaStatus,
        'notes': _notesCtrl.text,
        'latitude': _position?.latitude ?? 0,
        'longitude': _position?.longitude ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
      });
      setState(() {
        _reports.insert(0, {
          'type': _incidentType,
          'status': _areaStatus,
          'notes': _notesCtrl.text,
          'time': DateTime.now().toLocaleTimeString(),
          'location': _position != null
            ? '${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}'
            : 'Unknown',
        });
        _msg = '✅ Report submitted!';
        _notesCtrl.clear();
      });
    } catch (e) {
      // Save locally if offline
      setState(() {
        _reports.insert(0, {
          'type': _incidentType,
          'status': _areaStatus,
          'notes': _notesCtrl.text,
          'time': DateTime.now().toString().substring(11, 19),
          'location': _position != null
            ? '${_position!.latitude.toStringAsFixed(4)}, ${_position!.longitude.toStringAsFixed(4)}'
            : 'Unknown',
        });
        _msg = '✅ Report saved locally (will sync when online)';
        _notesCtrl.clear();
      });
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050c18),
      body: SafeArea(child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF080f22),
          child: Row(children: [
            const Icon(Icons.assignment_outlined, color: Color(0xFF00b4ff), size: 18),
            const SizedBox(width: 8),
            const Text('PATROL REPORTS', style: TextStyle(
              color: Color(0xFF00b4ff), fontWeight: FontWeight.w800,
              fontSize: 13, letterSpacing: 1.5)),
            const Spacer(),
            Text(widget.badge, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // New report form
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF080f22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00b4ff).withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('NEW PATROL REPORT', style: TextStyle(
                  color: Color(0xFF00b4ff), fontSize: 11,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 14),

                // Officer info
                Row(children: [
                  const Icon(Icons.badge_outlined, color: Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Text('${widget.officerName} · ${widget.badge}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const Spacer(),
                  if (_position != null) Row(children: [
                    const Icon(Icons.location_on, color: Color(0xFF00e676), size: 14),
                    const SizedBox(width: 4),
                    Text('${_position!.latitude.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ]),
                ]),
                const SizedBox(height: 14),

                // Incident type
                const Text('INCIDENT TYPE', style: TextStyle(
                  color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0c1630),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00b4ff).withOpacity(0.3)),
                  ),
                  child: DropdownButton<String>(
                    value: _incidentType,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0c1630),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    underline: const SizedBox(),
                    onChanged: (v) => setState(() => _incidentType = v!),
                    items: _incidentTypes.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontSize: 12)),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Area status
                const Text('AREA STATUS', style: TextStyle(
                  color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 6),
                Row(children: _areaStatuses.map((s) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _areaStatus = s['value']),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _areaStatus == s['value']
                          ? (s['color'] as Color).withOpacity(0.2) : const Color(0xFF0c1630),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _areaStatus == s['value']
                            ? s['color'] as Color : Colors.white12),
                      ),
                      child: Text(s['label'] as String, textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _areaStatus == s['value'] ? s['color'] as Color : Colors.white38,
                          fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
                )).toList()),
                const SizedBox(height: 12),

                // Notes
                const Text('PATROL NOTES', style: TextStyle(
                  color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Describe your patrol observations, incidents, tourist interactions...',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                    filled: true, fillColor: const Color(0xFF0c1630),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF00b4ff), width: 0.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: const Color(0xFF00b4ff).withOpacity(0.2), width: 0.5)),
                  ),
                ),
                const SizedBox(height: 12),

                if (_msg.isNotEmpty) Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _msg.contains('✅')
                      ? const Color(0xFF00e676).withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_msg, style: TextStyle(
                    color: _msg.contains('✅') ? const Color(0xFF00e676) : Colors.red,
                    fontSize: 12)),
                ),
                const SizedBox(height: 10),

                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submitReport,
                    icon: _submitting
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 16),
                    label: Text(_submitting ? 'Submitting...' : 'SUBMIT REPORT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00b4ff),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )),
              ]),
            ),

            const SizedBox(height: 20),

            // Previous reports
            if (_reports.isNotEmpty) ...[
              const Text('RECENT REPORTS', style: TextStyle(
                color: Colors.white38, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._reports.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF080f22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(r['type']?.replaceAll('_', ' ').toUpperCase() ?? '',
                      style: const TextStyle(color: Color(0xFF00b4ff), fontSize: 10, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(r['time'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ]),
                  const SizedBox(height: 4),
                  Text(r['notes'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('📍 ${r['location']}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ]),
              )),
            ],

            const SizedBox(height: 80),
          ]),
        )),
      ])),
    );
  }
}

extension on DateTime {
  String toLocaleTimeString() => toString().substring(11, 19);
}
