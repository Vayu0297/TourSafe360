import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _userName = 'Tourist';
  Position? _position;
  double _accelMag = 0;
  String _fallPhase = 'normal';
  bool _fallDetected = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  Timer? _locationTimer;
  final List<double> _accelWindow = [];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _accelSub;

  static const double FALL_THRESHOLD = 2.5;
  static const double IMPACT_THRESHOLD = 3.8;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(_pulseController);
    _loadUser();
    _startLocation();
    _startFallDetection();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userName = prefs.getString('user_name') ?? 'Tourist');
  }

  Future<void> _startLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;
    _updateLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateLocation());
  }

  Future<void> _updateLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _position = pos);
      await ApiService.updateLocation(pos.latitude, pos.longitude, '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}');
    } catch (e) {}
  }

  void _startFallDetection() {
    _accelSub = accelerometerEventStream().listen((event) {
      final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z) / 9.8;
      _accelWindow.add(mag);
      if (_accelWindow.length > 50) _accelWindow.removeAt(0);
      setState(() => _accelMag = mag);
      _detectFall(mag);
    });
  }

  void _detectFall(double mag) {
    if (_fallDetected) return;
    final recent = _accelWindow.length >= 10 ? _accelWindow.sublist(_accelWindow.length - 10) : _accelWindow;
    final avg = recent.isEmpty ? 1.0 : recent.reduce((a,b) => a+b) / recent.length;

    if (avg < 0.3) {
      setState(() => _fallPhase = 'freefall');
    } else if (mag > IMPACT_THRESHOLD) {
      setState(() => _fallPhase = 'impact');
      _triggerFallAlert(mag, true);
    } else if (mag > FALL_THRESHOLD && _fallPhase == 'freefall') {
      setState(() => _fallPhase = 'impact');
      _triggerFallAlert(mag, false);
    } else if (avg > 0.8 && avg < 1.2) {
      setState(() => _fallPhase = 'normal');
    }
  }

  void _triggerFallAlert(double force, bool needsAmbulance) {
    if (_fallDetected) return;
    setState(() { _fallDetected = true; _countdown = 10; });
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(needsAmbulance ? '🚑 Hard Fall Detected!' : '⚠️ Fall Detected!',
          style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Impact: ${force.toStringAsFixed(1)}g\n${needsAmbulance ? "Ambulance + Police" : "Police"} will be notified in 10 seconds.\n\nAre you okay?'),
        actions: [
          TextButton(
            onPressed: () { _cancelFall(); Navigator.pop(context); },
            child: const Text("I'm OK - Cancel", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _sendFallSOS(force, needsAmbulance); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send NOW', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) { t.cancel(); _sendFallSOS(force, needsAmbulance); }
    });
  }

  void _cancelFall() {
    _countdownTimer?.cancel();
    setState(() { _fallDetected = false; _fallPhase = 'normal'; _countdown = 0; });
    _accelWindow.clear();
  }

  Future<void> _sendFallSOS(double force, bool needsAmbulance) async {
    _countdownTimer?.cancel();
    try {
      final lat = _position?.latitude ?? 0;
      final lng = _position?.longitude ?? 0;
      final type = needsAmbulance ? 'medical' : 'accident';
      final msg = needsAmbulance
        ? 'AUTO FALL: ${force.toStringAsFixed(1)}g impact. AMBULANCE REQUIRED.'
        : 'AUTO FALL: ${force.toStringAsFixed(1)}g impact. Police needed.';
      final res = await ApiService.triggerSOS(type, lat, lng, msg);
      if (mounted) {
        showDialog(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(needsAmbulance ? '🚑 Ambulance + Police Notified!' : '🚔 Police Notified!'),
          content: Text('Severity: ${res['severity']?.toString().toUpperCase() ?? 'HIGH'}\nDispatched: ${res['nearest_police']?['name'] ?? 'Nearest station'}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ));
      }
    } catch (e) {}
    setState(() { _fallDetected = false; _fallPhase = 'normal'; _countdown = 0; });
  }

  Color get _phaseColor {
    switch (_fallPhase) {
      case 'freefall': return Colors.orange;
      case 'impact': return Colors.red;
      case 'post_fall': return Colors.purple;
      default: return Colors.green;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _accelSub?.cancel();
    _locationTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false, pinned: true,
            backgroundColor: const Color(0xFF6C63FF),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF6C63FF), Color(0xFFa855f7)]),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('Hi, ${_userName.split(' ')[0]}! 👋',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          const Text('Protected by AI 🛡️', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ]),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: const Text('SAFE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // Fall alert banner
              if (_fallDetected)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfef2f2), borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: Column(children: [
                    const Text('⚠️ FALL DETECTED!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.red)),
                    Text('Sending alert in $_countdown seconds...', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.red)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _cancelFall,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("I'm OK — Cancel Alert", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),

              // Sensor card
              _card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('📡 Fall Detection Sensor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: _phaseColor, shape: BoxShape.circle)),
                  ]),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _sensorStat('${_accelMag.toStringAsFixed(2)}g', 'G-Force'),
                    _sensorStat(_fallPhase.toUpperCase(), 'Status', color: _phaseColor),
                    _sensorStat('🟢', 'Active'),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_accelMag / 5).clamp(0, 1),
                      backgroundColor: const Color(0xFFf0e8ff),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _accelMag > IMPACT_THRESHOLD ? Colors.red : _accelMag > FALL_THRESHOLD ? Colors.orange : Colors.green,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Fall: ${FALL_THRESHOLD}g | Ambulance: ${IMPACT_THRESHOLD}g', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ]),
              ),

              const SizedBox(height: 12),

              // Location card
              _card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('📍 Your Location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_position != null) ...[
                    Text('${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
                    const SizedBox(height: 4),
                    const Text('✅ Shared with police in real-time', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                  ] else
                    const Text('Fetching location...', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _updateLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFf0e8ff), borderRadius: BorderRadius.circular(10)),
                      child: const Center(child: Text('🔄 Update Location', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600))),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // Quick SOS
              _card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('⚡ Quick SOS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _quickSosBtn('🆘', 'SOS', Colors.red, 'sos'),
                    const SizedBox(width: 8),
                    _quickSosBtn('🏥', 'Medical', Colors.orange, 'medical'),
                    const SizedBox(width: 8),
                    _quickSosBtn('🚗', 'Accident', Colors.amber, 'accident'),
                  ]),
                ]),
              ),

              const SizedBox(height: 12),

              // Safety tips
              _card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💡 Safety Tips for NE India', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (final tip in [
                    '🏔️ Always inform someone before trekking',
                    '📱 Keep phone charged above 30%',
                    '🌧️ Check weather before outdoor activities',
                    '🏥 Know nearest hospital location',
                    '🔦 Carry torch for night travel',
                  ]) Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(tip, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
                  ),
                ]),
              ),

              const SizedBox(height: 80),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.08), blurRadius: 20, offset: const Offset(0,4))],
      ),
      child: child,
    );
  }

  Widget _sensorStat(String value, String label, {Color? color}) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color ?? const Color(0xFF333333))),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }

  Widget _quickSosBtn(String emoji, String label, Color color, String type) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          // Confirm before sending
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('$emoji Send $label Alert?'),
              content: Text('This will notify police immediately.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  child: Text('Send $label', style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          if (confirm != true) return;
          final lat = _position?.latitude ?? 26.1445;
          final lng = _position?.longitude ?? 91.7362;
          try {
            final res = await ApiService.triggerSOS(type, lat, lng, 'Quick $label alert from tourist app');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('✅ $label alert sent! Police notified.'),
                backgroundColor: color,
                duration: const Duration(seconds: 3),
              ));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('❌ Failed: ${e.toString().substring(0, 50)}'),
                backgroundColor: Colors.red,
              ));
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ),
    );
  }
}
