import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  final String officerName;
  const MapScreen({super.key, required this.officerName});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<dynamic> _tourists = [];
  List<dynamic> _sosList = [];
  List<dynamic> _geofences = [];
  Position? _myPosition;
  final MapController _mapController = MapController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startTracking();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    try {
      final t = await PatrolApiService.getTourists();
      final s = await PatrolApiService.getAllSOS();
      final g = await PatrolApiService.getGeofences();
      setState(() { _tourists = t; _sosList = s; _geofences = g; });
    } catch (e) {}
  }

  Future<void> _startTracking() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) return;
    final pos = await Geolocator.getCurrentPosition();
    setState(() => _myPosition = pos);
    await PatrolApiService.updatePatrolLocation(
      pos.latitude, pos.longitude, widget.officerName);
    Timer.periodic(const Duration(seconds: 30), (_) async {
      final p = await Geolocator.getCurrentPosition();
      setState(() => _myPosition = p);
      await PatrolApiService.updatePatrolLocation(
        p.latitude, p.longitude, widget.officerName);
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Color _zoneColor(String? type) {
    switch (type) {
      case 'red': case 'restricted': return Colors.red;
      case 'amber': return Colors.orange;
      default: return const Color(0xFF00e676);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSOS = _sosList.where((s) => s['status'] == 'active').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF050c18),
      body: SafeArea(child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF080f22),
          child: Row(children: [
            const Icon(Icons.map_outlined, color: Color(0xFF00b4ff), size: 18),
            const SizedBox(width: 8),
            const Text('LIVE PATROL MAP', style: TextStyle(
              color: Color(0xFF00b4ff), fontWeight: FontWeight.w800,
              fontSize: 13, letterSpacing: 1.5)),
            const Spacer(),
            Text('${_tourists.length} tourists', style: const TextStyle(
              color: Colors.white38, fontSize: 11)),
            const SizedBox(width: 12),
            if (activeSOS.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.5))),
                child: Text('${activeSOS.length} SOS',
                  style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
          ]),
        ),

        // Map
        Expanded(child: Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myPosition != null
                ? LatLng(_myPosition!.latitude, _myPosition!.longitude)
                : const LatLng(26.2006, 92.9376),
              initialZoom: 8,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a','b','c','d'],
                userAgentPackageName: 'com.toursafe360.toursafe_patrol',
              ),

              // Geofence zones
              CircleLayer(circles: _geofences.map((g) {
                final color = _zoneColor(g['zone_type']);
                return CircleMarker(
                  point: LatLng(g['center_lat'] ?? 26.2, g['center_lng'] ?? 92.9),
                  radius: (g['radius_meters'] ?? 5000).toDouble(),
                  color: color.withOpacity(0.08),
                  borderColor: color.withOpacity(0.5),
                  borderStrokeWidth: 1.5,
                  useRadiusInMeter: true,
                );
              }).toList()),

              // Tourist markers
              MarkerLayer(markers: _tourists
                .where((t) => t['current_lat'] != null && t['current_lng'] != null)
                .map((t) {
                  final hasSOS = activeSOS.any((s) => s['tourist_name'] == t['name']);
                  return Marker(
                    point: LatLng(t['current_lat'], t['current_lng']),
                    width: 50, height: 50,
                    child: GestureDetector(
                      onTap: () => _showTouristInfo(t),
                      child: Column(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasSOS ? Colors.red : const Color(0xFF00b4ff),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(
                              color: (hasSOS ? Colors.red : const Color(0xFF00b4ff)).withOpacity(0.6),
                              blurRadius: 8, spreadRadius: 2)],
                          ),
                          child: Center(child: Text(
                            t['name']?.toString().substring(0, 1) ?? 'T',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
                        ),
                      ]),
                    ),
                  );
                }).toList()),

              // SOS markers
              MarkerLayer(markers: activeSOS
                .where((s) => s['latitude'] != null && s['longitude'] != null)
                .map((s) => Marker(
                  point: LatLng(s['latitude'], s['longitude']),
                  width: 44, height: 44,
                  child: GestureDetector(
                    onTap: () => _showSOSInfo(s),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Colors.red,
                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.7), blurRadius: 12, spreadRadius: 4)],
                      ),
                      child: const Icon(Icons.sos, color: Colors.white, size: 24),
                    ),
                  ),
                )).toList()),

              // My patrol location
              if (_myPosition != null)
                MarkerLayer(markers: [Marker(
                  point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
                  width: 48, height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00e5cc),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: const Color(0xFF00e5cc).withOpacity(0.6), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.local_police, color: Colors.white, size: 24),
                  ),
                )]),
            ],
          ),

          // Floating buttons
          Positioned(bottom: 16, right: 16, child: Column(children: [
            FloatingActionButton.small(
              heroTag: 'center',
              backgroundColor: const Color(0xFF00b4ff),
              onPressed: () {
                if (_myPosition != null) {
                  _mapController.move(
                    LatLng(_myPosition!.latitude, _myPosition!.longitude), 14);
                }
              },
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'refresh',
              backgroundColor: const Color(0xFF080f22),
              onPressed: _fetchData,
              child: const Icon(Icons.refresh, color: Color(0xFF00b4ff)),
            ),
          ])),

          // Legend
          Positioned(top: 10, left: 10,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF080f22).withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00b4ff).withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('LEGEND', style: TextStyle(color: Color(0xFF00b4ff), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 6),
                _legendItem(const Color(0xFF00b4ff), 'Tourist (safe)'),
                _legendItem(Colors.red, 'Tourist (SOS)'),
                _legendItem(const Color(0xFF00e5cc), 'Your location'),
                _legendItem(const Color(0xFF00e676), 'Safe zone'),
                _legendItem(Colors.orange, 'Caution zone'),
                _legendItem(Colors.red.withOpacity(0.7), 'Danger zone'),
              ]),
            ),
          ),
        ])),
      ])),
    );
  }

  Widget _legendItem(Color color, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]),
  );

  void _showTouristInfo(dynamic t) {
    showModalBottomSheet(context: context,
      backgroundColor: const Color(0xFF080f22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['name'] ?? 'Tourist', style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(t['nationality'] ?? '', style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          if (t['current_lat'] != null)
            Text('📍 ${t['current_lat']?.toStringAsFixed(5)}, ${t['current_lng']?.toStringAsFixed(5)}',
              style: const TextStyle(color: Color(0xFF00b4ff), fontSize: 12)),
          Text('🩸 ${t['blood_group'] ?? 'Unknown'}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text('📞 ${t['emergency_contact'] ?? 'Not set'}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); _mapController.move(
                LatLng(t['current_lat'], t['current_lng']), 15); },
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Navigate to Tourist'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00b4ff)),
            )),
        ]),
      ));
  }

  void _showSOSInfo(dynamic s) {
    showModalBottomSheet(context: context,
      backgroundColor: const Color(0xFF080f22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.sos, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(s['tourist_name'] ?? 'SOS Alert', style: const TextStyle(
              color: Colors.red, fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text('Type: ${s['alert_type'] ?? 'Emergency'}',
            style: const TextStyle(color: Colors.orange, fontSize: 13)),
          Text('Severity: ${s['severity']?.toString().toUpperCase() ?? 'HIGH'}',
            style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w700)),
          if (s['message'] != null)
            Text('Message: ${s['message']}',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await PatrolApiService.updateSOSStatus(s['id'], 'responding', 'Officer');
              },
              icon: const Icon(Icons.local_police, size: 16),
              label: const Text('Responding'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await PatrolApiService.updateSOSStatus(s['id'], 'resolved', 'Officer');
              },
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('Resolved'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00e676)),
            )),
          ]),
        ]),
      ));
  }
}
