import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'ecosystem_sections.dart';

/// Testi sezioni ecosistema da BackOffice (`settings/ecosystem_sections`).
abstract final class EcosystemSectionsConfigService {
  static const docId = 'ecosystem_sections';

  static Map<String, dynamic>? _sectionsConfig;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  static final StreamController<Map<String, dynamic>?> _sectionsController =
      StreamController<Map<String, dynamic>?>.broadcast();

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('settings').doc(docId);

  static void start() {
    _subscription?.cancel();
    _subscription = _doc.snapshots(includeMetadataChanges: true).listen(
      (snapshot) {
        if (!_isAuthoritativeSnapshot(snapshot)) return;
        _publishSections(_readSections(snapshot.data()));
      },
      onError: (_, __) {},
    );
  }

  static bool _isAuthoritativeSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.metadata.hasPendingWrites ||
        !snapshot.metadata.isFromCache;
  }

  static void _publishSections(Map<String, dynamic>? sections) {
    _sectionsConfig = sections;
    if (!_sectionsController.isClosed) {
      _sectionsController.add(sections);
    }
  }

  static void stop() {
    _subscription?.cancel();
    _subscription = null;
    _sectionsConfig = null;
  }

  static Stream<List<CreditCoreEcosystemSection>> watchSections() {
    start();
    return Stream.multi((controller) {
      controller.add(sectionsForDisplay());
      final sub = _sectionsController.stream.listen(
        (_) => controller.add(sectionsForDisplay()),
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  /// Stream grezzo `sections` da Firestore (BackOffice).
  static Stream<Map<String, dynamic>?> watchSectionsConfig() {
    start();
    return Stream.multi((controller) {
      controller.add(_sectionsConfig);
      final sub = _sectionsController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  static List<CreditCoreEcosystemSection> sectionsForDisplay() {
    return [
      for (final id in defaultEcosystemSectionIds)
        _sectionForDisplay(id, _sectionsConfig?[id]),
    ];
  }

  static CreditCoreEcosystemSection? sectionForId(String id) {
    final normalized = id.trim().toLowerCase();
    for (final section in sectionsForDisplay()) {
      if (section.id == normalized) return section;
    }
    return null;
  }

  static Map<String, dynamic>? _readSections(Map<String, dynamic>? data) {
    final sections = data?['sections'];
    if (sections is Map<String, dynamic>) return sections;
    if (sections is Map) return Map<String, dynamic>.from(sections);
    return null;
  }

  static CreditCoreEcosystemSection _sectionForDisplay(
    String id,
    dynamic raw,
  ) {
    final defaults = defaultEcosystemSectionForId(id);
    if (raw is! Map) return defaults;

    final map = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw);

    final highlights = _readHighlights(map['highlights']) ?? defaults.highlights;

    return defaults.copyWith(
      title: _readString(map['title']) ?? defaults.title,
      subtitle: _readString(map['subtitle']) ?? defaults.subtitle,
      body: _readString(map['body']) ?? defaults.body,
      highlights: highlights,
    );
  }

  static String? _readString(dynamic raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static List<String>? _readHighlights(dynamic raw) {
    if (raw is! List) return null;
    final items = raw
        .map((e) => e.toString().trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return items.isEmpty ? null : items;
  }
}
