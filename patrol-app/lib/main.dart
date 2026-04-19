import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('patrol_token');
  runApp(PatrolApp(isLoggedIn: token != null));
}

class PatrolApp extends StatelessWidget {
  final bool isLoggedIn;
  const PatrolApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TourSafe360 Patrol',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00b4ff),
          secondary: const Color(0xFF00e5cc),
          surface: const Color(0xFF080f22),
        ),
        scaffoldBackgroundColor: const Color(0xFF050c18),
        useMaterial3: true,
      ),
      home: isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}
