import 'package:cloud_firestore/cloud_firestore.dart';

class SessionInfo {
  final String sessionId;
  final String userId;
  final String deviceId;
  final String deviceType;
  final String deviceLabel;
  final String platform;
  final DateTime? lastActivity;
  final bool active;

  const SessionInfo({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.deviceType,
    required this.deviceLabel,
    required this.platform,
    required this.lastActivity,
    required this.active,
  });

  factory SessionInfo.fromFirestore(Map<String, dynamic> data) {
    final last = data['lastActivity'];
    return SessionInfo(
      sessionId: (data['sessionId'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      deviceId: (data['deviceId'] ?? '').toString(),
      deviceType: (data['deviceType'] ?? '').toString(),
      deviceLabel: (data['deviceLabel'] ?? '').toString(),
      platform: (data['platform'] ?? '').toString(),
      lastActivity: last is Timestamp ? last.toDate() : null,
      active: data['active'] == true,
    );
  }

  String get platformLabel {
    switch (platform) {
      case 'calc_store':
        return 'App CreditCalc Store';
      case 'planet_web':
        return 'CreditPlanet Web';
      default:
        return platform.isNotEmpty ? platform : 'CreditCore';
    }
  }

  String get conflictSummary =>
      '$deviceLabel\n$platformLabel ($deviceType)';

  Map<String, dynamic> toFirestore() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'deviceId': deviceId,
      'deviceType': deviceType,
      'deviceLabel': deviceLabel,
      'platform': platform,
      'lastActivity': FieldValue.serverTimestamp(),
      'active': active,
    };
  }
}
