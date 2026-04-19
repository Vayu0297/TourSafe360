import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class ZoneMapScreen extends StatefulWidget {
  const ZoneMapScreen({super.key});
  @override
  State<ZoneMapScreen> createState() => _ZoneMapScreenState();
}

class _ZoneMapScreenState extends State<ZoneMapScreen> with TickerProviderStateMixin {
  List<dynamic> _zones = [];
  Position? _position;
  Map<String,dynamic>? _currentZone;
  String _zoneStatus = 'safe';
  Timer? _locationTimer;
  Timer? _newsTimer;
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  bool _loading = true;

  // NE India news updates
  final List<Map<String,String>> _newsItems = [
    {'title':'🌧️ Heavy rainfall alert in Cherrapunji','time':'2 min ago','type':'weather'},
    {'title':'🐘 Elephant movement near Kaziranga highway','time':'15 min ago','type':'wildlife'},
    {'title':'🏔️ Tawang road landslide cleared','time':'1 hr ago','type':'road'},
    {'title':'✅ Majuli ferry service resumed','time':'2 hr ago','type':'transport'},
    {'title':'⚠️ Flash flood warning in Dzukou Valley','time':'3 hr ago','type':'weather'},
    {'title':'🎉 Hornbill Festival route open','time':'5 hr ago','type':'event'},
    {'title':'🏥 New medical post opened at Dzukou base','time':'6 hr ago','type':'medical'},
    {'title':'📡 Network restored in Tawang district','time':'8 hr ago','type':'network'},
  ];
  int _newsIndex = 0;

  static const Map<String,Color> _zoneColors = {
    'green': Color(0xFF22c55e),
    'amber': Color(0xFFf97316),
    'red': Color(0xFFef4444),
    'restricted': Color(0xFF7c3aed),
    'safe': Color(0xFF22c55e),
  };

  static const Map<String,String> _zoneMessages = {
    'green': '✅ You are in a SAFE zone. Enjoy your visit!',
    'amber': '⚠️ CAUTION zone. Stay on marked trails.',
    'red': '🚨 DANGER zone! Move to safe area immediately.',
    'restricted': '🚫 RESTRICTED zone! Exit immediately.',
    'safe': '✅ No zone restrictions. Safe to explore.',
  };

  static const Map<String,Color> _zoneBg = {
    'green': Color(0xFFf0fdf4),
    'amber': Color(0xFFfff7ed),
    'red': Color(0xFFfef2f2),
    'restricted': Color(0xFFf5f3ff),
    'safe': Color(0xFFf8f0ff),
  };

  Color get _primaryColor => _zoneColors[_zoneStatus] ?? const Color(0xFF6C63FF);
  Color get _bgColor => _zoneBg[_zoneStatus] ?? const Color(0xFFf8f0ff);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(_pulseController);
    _loadData();
    _startTracking();
    _startNewsRotation();
  }

  Future<void> _loadData() async {
    try {
      final zones = await ApiService.getZones();
      setState(() { _zones = zones; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _startTracking() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;
    await _updateLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) => _updateLocation());
  }

  Future<void> _updateLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _position = pos);
      _checkZones(pos);
      await ApiService.updateLocation(pos.latitude, pos.longitude,
        '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');
    } catch (e) {}
  }

  void _checkZones(Position pos) {
    String newStatus = 'safe';
    Map<String,dynamic>? insideZone;

    for (final zone in _zones) {
      final dist = _distance(pos.latitude, pos.longitude,
        zone['center_lat'] ?? 0, zone['center_lng'] ?? 0);
      if (dist < (zone['radius_meters'] ?? 5000)) {
        insideZone = zone;
        newStatus = zone['zone_type'] ?? 'green';
        break;
      }
    }

    if (newStatus != _zoneStatus) {
      setState(() { _zoneStatus = newStatus; _currentZone = insideZone; });
      if (newStatus == 'red' || newStatus == 'restricted') {
        _showZoneAlert(newStatus, insideZone);
      }
    }
  }

  double _distance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat/2)*sin(dLat/2) +
              cos(lat1*pi/180)*cos(lat2*pi/180)*sin(dLng/2)*sin(dLng/2);
    return R * 2 * atan2(sqrt(a), sqrt(1-a));
  }

  void _showZoneAlert(String type, Map<String,dynamic>? zone) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: _bgColor,
      title: Text(type == 'restricted' ? '🚫 Restricted Zone!' : '🚨 Danger Zone!',
        style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(zone?['name'] ?? 'Unknown zone', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Text(_zoneMessages[type] ?? '', style: const TextStyle(fontSize: 14)),
        if (zone?['description'] != null) ...[
          const SizedBox(height: 8),
          Text(zone!['description'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ]),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
          child: const Text('Got it', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _startNewsRotation() {
    _newsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() => _newsIndex = (_newsIndex + 1) % _newsItems.length);
    });
  }

  void _centerOnMe() {
    if (_position != null) {
      _mapController.move(LatLng(_position!.latitude, _position!.longitude), 14);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationTimer?.cancel();
    _newsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(children: [

        // Dynamic header based on zone
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('🗺️ Zone Map', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                      child: Text(_zoneStatus.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(_zoneMessages[_zoneStatus] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
                if (_currentZone != null) ...[
                  const SizedBox(height: 4),
                  Text('📍 ${_currentZone!['name']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
          ),
        ),

        // Live news ticker
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          color: _primaryColor.withOpacity(0.1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(6)),
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _newsItems[_newsIndex]['title']!,
                  key: ValueKey(_newsIndex),
                  style: TextStyle(fontSize: 12, color: _primaryColor, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(_newsItems[_newsIndex]['time']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
        ),

        // Map
        Expanded(
          child: Stack(children: [
            _loading
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _position != null
                      ? LatLng(_position!.latitude, _position!.longitude)
                      : const LatLng(26.2006, 92.9376),
                    initialZoom: 8,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.toursafe360.toursafe360',
                    ),

                    // Zone circles
                    CircleLayer(circles: _zones.map((zone) {
                      final color = _zoneColors[zone['zone_type']] ?? Colors.blue;
                      return CircleMarker(
                        point: LatLng(zone['center_lat'] ?? 0, zone['center_lng'] ?? 0),
                        radius: (zone['radius_meters'] ?? 5000).toDouble(),
                        color: color.withOpacity(0.15),
                        borderColor: color,
                        borderStrokeWidth: 2,
                        useRadiusInMeter: true,
                      );
                    }).toList()),

                    // Zone labels
                    MarkerLayer(markers: _zones.map((zone) => Marker(
                      point: LatLng(zone['center_lat'] ?? 0, zone['center_lng'] ?? 0),
                      width: 120, height: 30,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_zoneColors[zone['zone_type']] ?? Colors.blue).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(zone['name'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                      ),
                    )).toList()),

                    // Tourist location
                    if (_position != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(_position!.latitude, _position!.longitude),
                          width: 60, height: 60,
                          child: Column(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
                              ),
                              child: const Center(child: Text('👤', style: TextStyle(fontSize: 20))),
                            ),
                          ]),
                        ),
                      ]),
                  ],
                ),

            // Center on me button
            Positioned(
              bottom: 16, right: 16,
              child: FloatingActionButton(
                onPressed: _centerOnMe,
                backgroundColor: _primaryColor,
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),

            // Zone legend
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Legend', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  for (final e in [
                    ['green', '🟢 Safe'],
                    ['amber', '🟡 Caution'],
                    ['red', '🔴 Danger'],
                    ['restricted', '🟣 Restricted'],
                  ]) Row(children: [
                    Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(color: _zoneColors[e[0]], shape: BoxShape.circle)),
                    Text(e[1], style: const TextStyle(fontSize: 10)),
                  ]),
                ]),
              ),
            ),
          ]),
        ),

        // News feed bottom
        Container(
          height: 120,
          color: Colors.white,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('📰 NE India Updates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primaryColor)),
                Text('Live', style: TextStyle(fontSize: 11, color: _primaryColor)),
              ]),
            ),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _newsItems.length,
                itemBuilder: (_, i) {
                  final news = _newsItems[i];
                  final typeColor = news['type'] == 'weather' ? Colors.blue :
                                   news['type'] == 'wildlife' ? Colors.green :
                                   news['type'] == 'road' ? Colors.orange : Colors.purple;
                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: typeColor.withOpacity(0.2)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(news['title']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: typeColor.withValues(alpha: 0.8)), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Text(news['time']!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
