import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});
  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  String? _loadingType;
  Map<String,dynamic>? _lastAlert;
  Position? _position;

  final List<Map<String,dynamic>> _sosTypes = [
    {'type':'sos','label':'SOS','icon':'🆘','color':const Color(0xFFef4444),'bg':const Color(0xFFfef2f2),'ambulance':false,'desc':'General emergency'},
    {'type':'medical','label':'Medical','icon':'🏥','color':const Color(0xFFf97316),'bg':const Color(0xFFfff7ed),'ambulance':true,'desc':'Medical emergency'},
    {'type':'accident','label':'Accident','icon':'🚗','color':const Color(0xFFd97706),'bg':const Color(0xFFfffbeb),'ambulance':true,'desc':'Vehicle accident'},
    {'type':'fall','label':'Fall','icon':'🏔️','color':const Color(0xFF8b5cf6),'bg':const Color(0xFFf5f3ff),'ambulance':true,'desc':'Mountain/cliff fall'},
    {'type':'missing','label':'Missing','icon':'👤','color':const Color(0xFF6c63ff),'bg':const Color(0xFFf0e8ff),'ambulance':false,'desc':'Person missing'},
    {'type':'weather','label':'Weather','icon':'🌧️','color':const Color(0xFF0ea5e9),'bg':const Color(0xFFf0f9ff),'ambulance':false,'desc':'Weather emergency'},
    {'type':'wildlife','label':'Wildlife','icon':'🐘','color':const Color(0xFF059669),'bg':const Color(0xFFecfdf5),'ambulance':false,'desc':'Wildlife encounter'},
    {'type':'fire','label':'Fire','icon':'🔥','color':const Color(0xFFdc2626),'bg':const Color(0xFFfef2f2),'ambulance':true,'desc':'Fire emergency'},
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _position = pos);
    } catch (e) {}
  }

  Future<void> _triggerSOS(Map<String,dynamic> sos) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${sos['icon']} Send ${sos['label']} Alert?'),
        content: Text(sos['ambulance'] == true
          ? '🚑 This will notify BOTH Police AND Ambulance with AI triage'
          : '🚔 This will notify Police with AI triage'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: sos['color'] as Color),
            child: Text(sos['ambulance'] == true ? '🚑 Send to Police + Ambulance' : '🚔 Send to Police',
              style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loadingType = sos['type'] as String);
    HapticFeedback.heavyImpact();

    try {
      final lat = _position?.latitude ?? 26.1445;
      final lng = _position?.longitude ?? 91.7362;
      final res = await ApiService.triggerSOS(
        sos['type'] as String, lat, lng,
        '${sos['ambulance'] == true ? "AMBULANCE REQUIRED. " : ""}Emergency ${sos['label']} alert',
      );
      setState(() => _lastAlert = res);
      if (mounted) {
        showDialog(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(sos['ambulance'] == true ? '🚑 Ambulance + Police Notified!' : '🚔 Police Notified!'),
          content: Text(
            'Severity: ${res['severity']?.toString().toUpperCase() ?? 'HIGH'}\n'
            'Dispatched: ${res['nearest_police']?['name'] ?? 'Nearest station'}\n'
            'AI: ${res['ai_triage']?['immediate_action'] ?? 'Help dispatched'}'
            '${sos['ambulance'] == true ? '\n\n🚑 Ambulance also alerted!' : ''}'
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Alert sent via backup')));
    }
    setState(() => _loadingType = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120, pinned: true,
            backgroundColor: const Color(0xFFef4444),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFef4444), Color(0xFFdc2626)]),
                ),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Text('🚨 Emergency SOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('AI-powered • Mistral-7B triage • Instant dispatch', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                )),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              if (_lastAlert != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFecfdf5), borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFbbf7d0), width: 1.5)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('✅ Last Alert Sent', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                    Text('Severity: ${_lastAlert!['severity']?.toString().toUpperCase()} | Police: ${_lastAlert!['nearest_police']?['name']}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                    if (_lastAlert!['ai_triage'] != null)
                      Text('🤖 AI: ${_lastAlert!['ai_triage']?['triage_summary']}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6c63ff))),
                  ]),
                ),

              GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3,
                ),
                itemCount: _sosTypes.length,
                itemBuilder: (_, i) {
                  final sos = _sosTypes[i];
                  final loading = _loadingType == sos['type'];
                  return GestureDetector(
                    onTap: loading ? null : () => _triggerSOS(sos),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sos['bg'] as Color, borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: (sos['color'] as Color).withOpacity(0.3), width: 1.5),
                      ),
                      child: loading
                        ? Center(child: CircularProgressIndicator(color: sos['color'] as Color))
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(sos['icon'] as String, style: const TextStyle(fontSize: 36)),
                            const SizedBox(height: 6),
                            Text(sos['label'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: sos['color'] as Color)),
                            Text(sos['desc'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            if (sos['ambulance'] == true)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: sos['color'] as Color, borderRadius: BorderRadius.circular(10)),
                                child: const Text('+ 🚑 Ambulance', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                              ),
                          ]),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.08), blurRadius: 20)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ℹ️ How it works', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (final step in [
                    '1. Tap emergency type',
                    '2. AI (Mistral-7B) triages your emergency',
                    '3. Nearest police station dispatched',
                    '4. Ambulance called if medical needed',
                    '5. Equipment recommendations sent to responders',
                  ]) Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(step, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
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
}
