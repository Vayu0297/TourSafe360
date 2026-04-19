class PatrolTourist {
  final String id, name, nationality, flag, location, status, phone, emergencyContact;
  final double lat, lng;
  final int batteryPct, lastSeen;
  PatrolTourist({required this.id, required this.name, required this.nationality,
    required this.flag, required this.location, required this.lat, required this.lng,
    required this.status, required this.batteryPct, required this.lastSeen,
    required this.phone, required this.emergencyContact});
  factory PatrolTourist.fromJson(Map<String, dynamic> j) => PatrolTourist(
    id: '${j['id'] ?? ''}', name: '${j['name'] ?? 'Unknown'}',
    nationality: '${j['nationality'] ?? j['country'] ?? 'Unknown'}',
    flag: '${j['flag'] ?? '\u{1F30D}'}',
    location: '${j['current_location_name'] ?? j['location'] ?? 'Unknown'}',
    lat: ((j['current_lat'] ?? j['lat'] ?? 26.2) as num).toDouble(),
    lng: ((j['current_lng'] ?? j['lng'] ?? 92.5) as num).toDouble(),
    status: '${j['status'] ?? 'safe'}',
    batteryPct: ((j['battery_pct'] ?? j['battery'] ?? 100) as num).toInt(),
    lastSeen: ((j['last_seen'] ?? 0) as num).toInt(),
    phone: '${j['phone'] ?? ''}',
    emergencyContact: '${j['emergency_contact'] ?? ''}',
  );
}

class SOSAlert {
  final String id, touristName, type, severity, status, locationName, description, createdAt;
  final double lat, lng;
  final String? responder;
  final List<String> equipment;
  SOSAlert({required this.id, required this.touristName, required this.type,
    required this.severity, required this.status, required this.locationName,
    required this.lat, required this.lng, required this.description,
    required this.createdAt, this.responder, required this.equipment});
  factory SOSAlert.fromJson(Map<String, dynamic> j) {
    List<String> eq = [];
    final raw = j['equipment'] ?? (j['ai_triage'] is Map ? j['ai_triage']['equipment'] : null) ?? [];
    if (raw is List) eq = raw.map((e) => '$e').toList();
    return SOSAlert(
      id: '${j['id'] ?? j['alert_id'] ?? ''}',
      touristName: '${j['tourist_name'] ?? 'Unknown'}',
      type: '${j['type'] ?? j['alert_type'] ?? 'SOS'}',
      severity: '${j['severity'] ?? 'high'}',
      status: '${j['status'] ?? 'active'}',
      locationName: '${j['location_name'] ?? j['geofence_name'] ?? 'Unknown'}',
      lat: ((j['lat'] ?? j['latitude'] ?? 26.2) as num).toDouble(),
      lng: ((j['lng'] ?? j['longitude'] ?? 92.5) as num).toDouble(),
      description: '${j['description'] ?? j['message'] ?? ''}',
      createdAt: '${j['created_at'] ?? ''}',
      responder: j['responder']?.toString(),
      equipment: eq,
    );
  }
  SOSAlert copyWith({String? status, String? responder}) => SOSAlert(
    id: id, touristName: touristName, type: type, severity: severity,
    status: status ?? this.status, locationName: locationName, lat: lat, lng: lng,
    description: description, createdAt: createdAt,
    responder: responder ?? this.responder, equipment: equipment);
}

class PatrolLog {
  final String id, type, note, timestamp;
  final double lat, lng;
  PatrolLog({required this.id, required this.type, required this.note,
    required this.timestamp, required this.lat, required this.lng});
}

class ChatMessage {
  final String id, sender, senderType, text;
  final DateTime time;
  final bool isMe;
  ChatMessage({required this.id, required this.sender, required this.senderType,
    required this.text, required this.time, required this.isMe});
}
