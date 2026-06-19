import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Stati account allineati tra login, main e waiting.
class UserAccountStatus {
  UserAccountStatus._();

  static const _reasonKeys = [
    'motivazione',
    'blockReason',
    'block_reason',
    'reason',
    'blockNote',
  ];

  static const _dateKeys = [
    'blockedAt',
    'blocked_at',
    'blockDate',
    'dataBlocco',
    'disabledAt',
    'disabled_at',
  ];

  static bool isBlocked(String? status) {
    switch (status) {
      case 'blocked':
      case 'disabled':
      case 'standby':
        return true;
      default:
        return false;
    }
  }

  /// Stato da passare a [WaitingPage] (rosso = blocked).
  static String waitingStatus(String? status) {
    if (isBlocked(status)) return 'blocked';
    return status ?? 'pending';
  }

  /// Motivazione blocco da documento utente/azienda (backoffice).
  static String? blockReason(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in _reasonKeys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// Data blocco da documento utente/azienda (backoffice).
  static DateTime? blockDate(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in _dateKeys) {
      final value = data[key];
      if (value == null) continue;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
    }
    return null;
  }

  static String formatBlockDate(DateTime? date) {
    if (date == null) return '—';
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  static String formatBlockDateTime(DateTime? date) {
    if (date == null) return '—';
    final d = date.toLocal();
    return '${formatBlockDate(date)} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  /// Aggiorna `lastLoginAt` su Firestore (merge, non sovrascrive altri campi).
  static Future<void> recordLastLoginAt(String uid) async {
    if (uid.isEmpty) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Work con email verificata: migra `pending` → `active` su Firestore.
  static Future<bool> ensureWorkUserActivated({
    required User user,
    Map<String, dynamic>? userData,
  }) async {
    if (!user.emailVerified) return false;

    var data = userData;
    if (data == null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) return false;
      data = doc.data();
    }
    if (data == null) return false;

    if ((data['type'] ?? '').toString() != 'work') return false;

    final status = (data['status'] ?? 'pending').toString();
    if (status != 'pending') return false;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'status': 'active',
      'activatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  /// Stato work in lista supervisor (`pending` legacy → `active`).
  static String workCollaboratorStatus(String? status) {
    final value = (status ?? 'active').toString().trim();
    if (value == 'pending') return 'active';
    return value;
  }

  static String workStatusLabel(String status) {
    switch (workCollaboratorStatus(status)) {
      case 'active':
        return 'ATTIVO';
      case 'blocked':
        return 'BLOCCATO';
      case 'standby':
        return 'STANDBY';
      default:
        return status.toUpperCase();
    }
  }

  /// Aggiornamento Firestore per blocco / stand-by collaboratore work.
  static Map<String, dynamic> workModerationApply({
    required String status,
    required String motivazione,
    required String supervisorUid,
  }) {
    return {
      'status': status,
      'motivazione': motivazione,
      'blockedAt': FieldValue.serverTimestamp(),
      'blockedBy': supervisorUid,
    };
  }

  /// Ripristino accesso collaboratore work.
  static Map<String, dynamic> workModerationClear() {
    return {
      'status': 'active',
      'motivazione': FieldValue.delete(),
      'blockReason': FieldValue.delete(),
      'block_reason': FieldValue.delete(),
      'blockedAt': FieldValue.delete(),
      'blocked_at': FieldValue.delete(),
      'blockDate': FieldValue.delete(),
      'blockedBy': FieldValue.delete(),
    };
  }
}
