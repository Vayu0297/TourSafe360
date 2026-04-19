import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'sos_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'zone_map_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const SOSScreen(),
    const ZoneMapScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0,-4))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF6C63FF),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Text('🏠', style: TextStyle(fontSize: 24)), label: 'Home'),
            BottomNavigationBarItem(icon: Text('🚨', style: TextStyle(fontSize: 24)), label: 'SOS'),
            BottomNavigationBarItem(icon: Text('🗺️', style: TextStyle(fontSize: 24)), label: 'Zones'),
            BottomNavigationBarItem(icon: Text('🤖', style: TextStyle(fontSize: 24)), label: 'AI Chat'),
            BottomNavigationBarItem(icon: Text('👤', style: TextStyle(fontSize: 24)), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
