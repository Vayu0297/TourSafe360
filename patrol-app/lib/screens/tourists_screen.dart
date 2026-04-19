import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TouristsScreen extends StatefulWidget {
  const TouristsScreen({super.key});
  @override
  State<TouristsScreen> createState() => _TouristsScreenState();
}

class _TouristsScreenState extends State<TouristsScreen> {
  List<dynamic> _tourists = [];
  String _search = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _fetch() async {
    try {
      final t = await PatrolApiService.getTourists();
      setState(() => _tourists = t);
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _tourists.where((t) =>
      t['name']?.toString().toLowerCase().contains(_search.toLowerCase()) == true ||
      t['nationality']?.toString().toLowerCase().contains(_search.toLowerCase()) == true
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF050c18),
      body: SafeArea(child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: const Color(0xFF080f22),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.people_outlined, color: Color(0xFF00b4ff), size: 18),
              const SizedBox(width: 8),
              Text('TOURISTS (${_tourists.length})', style: const TextStyle(
                color: Color(0xFF00b4ff), fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5)),
              const Spacer(),
              GestureDetector(onTap: _fetch,
                child: const Icon(Icons.refresh, color: Colors.white38, size: 18)),
            ]),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search tourists...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                filled: true, fillColor: const Color(0xFF0c1630),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF00b4ff), width: 0.5)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: const Color(0xFF00b4ff).withOpacity(0.2), width: 0.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ]),
        ),

        Expanded(child: filtered.isEmpty
          ? const Center(child: Text('No tourists found', style: TextStyle(color: Colors.white38)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final t = filtered[i];
                final hasLoc = t['current_lat'] != null;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080f22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00b4ff).withOpacity(0.2), width: 0.5),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22, backgroundColor: const Color(0xFF0c1630),
                      child: Text(t['name']?.toString().substring(0, 1) ?? 'T',
                        style: const TextStyle(color: Color(0xFF00b4ff),
                          fontWeight: FontWeight.w800, fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t['name'] ?? 'Unknown', style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(t['nationality'] ?? '', style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                      if (t['blood_group'] != null && t['blood_group'].toString().isNotEmpty)
                        Text('🩸 ${t['blood_group']}', style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                      if (t['emergency_contact'] != null && t['emergency_contact'].toString().isNotEmpty)
                        Text('📞 ${t['emergency_contact']}', style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Icon(hasLoc ? Icons.location_on : Icons.location_off,
                        color: hasLoc ? const Color(0xFF00e676) : Colors.white24, size: 16),
                      const SizedBox(height: 4),
                      if (hasLoc) Text(
                        '${t['current_lat']?.toStringAsFixed(3)},\n${t['current_lng']?.toStringAsFixed(3)}',
                        style: const TextStyle(color: Colors.white24, fontSize: 9),
                        textAlign: TextAlign.right),
                    ]),
                  ]),
                );
              },
            )),
      ])),
    );
  }
}
