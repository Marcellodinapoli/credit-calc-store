import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ecosystem_sections.dart';
import 'ecosystem_sections_config_service.dart';

typedef EcosystemSectionsAdminVerifier = Future<bool> Function({
  bool forceRefresh,
});

/// Salvataggio testi sezioni ecosistema (BackOffice app + web).
abstract final class EcosystemSectionsAdminService {
  static const sectionIds = defaultEcosystemSectionIds;

  static void applySectionsConfig({
    required Map<String, dynamic>? sections,
    required void Function(String sectionId, Map<String, dynamic> payload)
        onSection,
  }) {
    for (final sectionId in sectionIds) {
      onSection(sectionId, buildSectionFormPayload(sectionId, sections?[sectionId]));
    }
  }

  static Map<String, dynamic> buildSectionFormPayload(
    String sectionId,
    dynamic raw,
  ) {
    final defaults = defaultEcosystemSectionForId(sectionId);
    final rawMap = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : null;

    return {
      'sectionId': sectionId,
      'title': (rawMap?['title'] ?? defaults.title).toString(),
      'subtitle': (rawMap?['subtitle'] ?? defaults.subtitle).toString(),
      'body': (rawMap?['body'] ?? defaults.body).toString(),
      'highlightsText': _highlightsToText(
        _readHighlights(rawMap?['highlights']) ?? defaults.highlights,
      ),
    };
  }

  static Map<String, dynamic> buildFirestoreSectionPayload(
    String sectionId,
    Map<String, dynamic> payload,
  ) {
    final highlights = _textToHighlights(
      payload['highlightsText']?.toString() ?? '',
    );
    if (highlights.isEmpty) {
      throw StateError(
        'Inserisci almeno una voce nell\'elenco per '
        '${defaultEcosystemSectionForId(sectionId).title}.',
      );
    }

    return {
      'title': payload['title']?.toString().trim() ?? '',
      'subtitle': payload['subtitle']?.toString().trim() ?? '',
      'body': payload['body']?.toString().trim() ?? '',
      'highlights': highlights,
    };
  }

  static Future<void> saveSections(
    Map<String, Map<String, dynamic>> sections, {
    required EcosystemSectionsAdminVerifier verifyAdmin,
  }) async {
    if (!await verifyAdmin(forceRefresh: true)) {
      throw StateError('Accesso negato');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance
        .collection('settings')
        .doc(EcosystemSectionsConfigService.docId)
        .set({
      'sections': sections,
      'updatedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  static String _highlightsToText(List<String> highlights) =>
      highlights.join('\n');

  static List<String> _textToHighlights(String raw) => raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  static List<String>? _readHighlights(dynamic raw) {
    if (raw is! List) return null;
    return _textToHighlights(raw.map((e) => e.toString()).join('\n'));
  }
}
