import 'package:cloud_firestore/cloud_firestore.dart';

class SessionInfo {
  final String sessionId;
  final String userId;
  final String deviceId;
  final String deviceType;
  final String deviceLabel;
  final DateTime? lastActivity;
  final bool active;

  const SessionInfo({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.deviceType,
    required this.deviceLabel,
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
      lastActivity: last is Timestamp ? last.toDate() : null,
      active: data['active'] == true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'deviceId': deviceId,
      'deviceType': deviceType,
      'deviceLabel': deviceLabel,
      'lastActivity': FieldValue.serverTimestamp(),
      'active': active,
    };
  }
}
