import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Position? last;
  static StreamSubscription<Position>? _sub;
  static Future<bool> requestPerm() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }
  static Future<Position?> getPosition() async {
    try {
      if (!await requestPerm()) return null;
      last = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      return last;
    } catch (_) { return null; }
  }
  static void startTracking(void Function(Position) cb) {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20))
        .listen((p) { last = p; cb(p); });
  }
  static void stop() => _sub?.cancel();
}
