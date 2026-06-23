import 'package:cloud_firestore/cloud_firestore.dart';

/// Contesto warm-up: sollecito o recupero.
enum WarmupContestationContext {
  sollecito,
  recupero;

  String get firestoreValue => name;

  String get label => switch (this) {
        WarmupContestationContext.sollecito => 'Sollecito',
        WarmupContestationContext.recupero => 'Recupero',
      };

  static WarmupContestationContext fromString(String? raw) {
    return switch (raw) {
      'recupero' => WarmupContestationContext.recupero,
      _ => WarmupContestationContext.sollecito,
    };
  }
}

/// Stato moderazione BK.
enum WarmupContestationStatus {
  draft,
  pendingReview,
  approved,
  rejected;

  String get firestoreValue => switch (this) {
        WarmupContestationStatus.draft => 'draft',
        WarmupContestationStatus.pendingReview => 'pending_review',
        WarmupContestationStatus.approved => 'approved',
        WarmupContestationStatus.rejected => 'rejected',
      };

  String get label => switch (this) {
        WarmupContestationStatus.draft => 'Bozza',
        WarmupContestationStatus.pendingReview => 'In valutazione',
        WarmupContestationStatus.approved => 'Condivisa',
        WarmupContestationStatus.rejected => 'Rifiutata',
      };

  static WarmupContestationStatus fromString(String? raw) {
    return switch (raw) {
      'pending_review' => WarmupContestationStatus.pendingReview,
      'approved' => WarmupContestationStatus.approved,
      'rejected' => WarmupContestationStatus.rejected,
      _ => WarmupContestationStatus.draft,
    };
  }
}

enum WarmupContestationCategory {
  economica,
  legale,
  salute,
  amministrativa,
  generica;

  String get label => switch (this) {
        WarmupContestationCategory.economica => 'Economica',
        WarmupContestationCategory.legale => 'Legale',
        WarmupContestationCategory.salute => 'Salute',
        WarmupContestationCategory.amministrativa => 'Amministrativa',
        WarmupContestationCategory.generica => 'Generica',
      };

  static WarmupContestationCategory fromString(String? raw) {
    return WarmupContestationCategory.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => WarmupContestationCategory.generica,
    );
  }
}

/// Contestazione inserita dall'utente (moderata dal backoffice).
class WarmupContestation {
  const WarmupContestation({
    required this.id,
    required this.authorUid,
    this.authorName,
    required this.context,
    required this.status,
    required this.title,
    required this.declared,
    required this.meaning,
    required this.risk,
    required this.objective,
    required this.response,
    this.userRawInput,
    this.category = WarmupContestationCategory.generica,
    this.rejectionNote,
    this.reviewedAt,
    this.reviewedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String authorUid;
  final String? authorName;
  final WarmupContestationContext context;
  final WarmupContestationStatus status;
  final String title;
  final String declared;
  final String meaning;
  final String risk;
  final String objective;
  final String response;
  final String? userRawInput;
  final WarmupContestationCategory category;
  final String? rejectionNote;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Chiave in `listening_progress.contestazioni`.
  String get progressKey => 'uc_$id';

  bool get canEdit => status != WarmupContestationStatus.approved;

  bool get canDelete => status != WarmupContestationStatus.approved;

  bool get isPendingReview =>
      status == WarmupContestationStatus.pendingReview;

  factory WarmupContestation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return WarmupContestation(
      id: doc.id,
      authorUid: (data['authorUid'] ?? '').toString(),
      authorName: data['authorName']?.toString(),
      context: WarmupContestationContext.fromString(data['context']?.toString()),
      status: WarmupContestationStatus.fromString(data['status']?.toString()),
      title: (data['title'] ?? '').toString(),
      declared: (data['declared'] ?? '').toString(),
      meaning: (data['meaning'] ?? '').toString(),
      risk: (data['risk'] ?? '').toString(),
      objective: (data['objective'] ?? '').toString(),
      response: (data['response'] ?? '').toString(),
      userRawInput: data['userRawInput']?.toString(),
      category: WarmupContestationCategory.fromString(
        data['category']?.toString(),
      ),
      rejectionNote: data['rejectionNote']?.toString(),
      reviewedAt: _readTimestamp(data['reviewedAt']),
      reviewedBy: data['reviewedBy']?.toString(),
      createdAt: _readTimestamp(data['createdAt']),
      updatedAt: _readTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap({
    required WarmupContestationStatus status,
  }) {
    return {
      'authorUid': authorUid,
      if (authorName != null && authorName!.isNotEmpty)
        'authorName': authorName,
      'context': context.firestoreValue,
      'status': status.firestoreValue,
      'title': title.trim(),
      'declared': declared.trim(),
      'meaning': meaning.trim(),
      'risk': risk.trim(),
      'objective': objective.trim(),
      'response': response.trim(),
      if (userRawInput != null && userRawInput!.trim().isNotEmpty)
        'userRawInput': userRawInput!.trim(),
      'category': category.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap({
    required WarmupContestationStatus status,
  }) {
    return {
      'title': title.trim(),
      'declared': declared.trim(),
      'meaning': meaning.trim(),
      'risk': risk.trim(),
      'objective': objective.trim(),
      'response': response.trim(),
      if (userRawInput != null && userRawInput!.trim().isNotEmpty)
        'userRawInput': userRawInput!.trim(),
      'category': category.name,
      'status': status.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _readTimestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    return null;
  }
}
