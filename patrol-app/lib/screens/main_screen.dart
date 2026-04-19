import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'sos_screen.dart';
import 'report_screen.dart';
import 'tourists_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  String _officerName = 'Officer';
  String _badge = 'PL-0000';
  int _sosBadge = 0;

  @override
  void initState() {
    super.initState();
    _loadOfficer();
  }

  Future<void> _loadOfficer() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _officerName = prefs.getString('officer_name') ?? 'Officer';
      _badge = prefs.getString('officer_badge') ?? 'PL-0000';
    });
  }

  void _updateSOSBadge(int count) => setState(() => _sosBadge = count);

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(officerName: _officerName, badge: _badge, onSOSUpdate: _updateSOSBadge),
      MapScreen(officerName: _officerName),
      SOSScreen(officerName: _officerName, onSOSUpdate: _updateSOSBadge),
      TouristsScreen(),
      ReportScreen(officerName: _officerName, badge: _badge),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF080f22),
          border: const Border(top: BorderSide(color: Color(0xFF00b4ff), width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          backgroundColor: const Color(0xFF080f22),
          selectedItemColor: const Color(0xFF00b4ff),
          unselectedItemColor: Colors.white24,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          elevation: 0,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Command'),
            const BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Live Map'),
            BottomNavigationBarItem(
              icon: Stack(children: [
                const Icon(Icons.sos_outlined),
                if (_sosBadge > 0) Positioned(right: 0, top: 0,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Center(child: Text('$_sosBadge',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800))),
                  )),
              ]),
              label: 'SOS',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.people_outlined), label: 'Tourists'),
            const BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Reports'),
          ],
        ),
      ),
    );
  }
}
