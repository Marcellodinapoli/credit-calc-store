import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Contesto azienda dopo validazione codice work (COL/SUP).
class WorkCompanyLinkContext {
  const WorkCompanyLinkContext({
    required this.workCode,
    required this.companyId,
    required this.companyCode,
    required this.companyName,
    required this.workRole,
  });

  final String workCode;
  final String companyId;
  final String companyCode;
  final String companyName;
  final String workRole;
}

/// Validazione codici Work (`work_codes`) per registrazione store.
abstract final class WorkCodeService {
  WorkCodeService._();

  static String normalizeCode(String input) {
    return input
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^A-Z0-9-]'), '');
  }

  static bool looksLikeWorkCode(String code) {
    return RegExp(r'^CP-[A-Z0-9]+-(COL|SUP)$').hasMatch(code);
  }

  static String asString(dynamic value) => (value ?? '').toString().trim();

  static String normalizeRoleValue(dynamic value) {
    final raw = asString(value).toLowerCase();
    if (raw == 'sup' || raw == 'supervisor') return 'supervisor';
    if (raw == 'col' || raw == 'collaborator') return 'collaborator';
    return raw;
  }

  static Future<WorkCodeValidationResult> validate(String rawCode) async {
    final code = normalizeCode(rawCode);
    if (code.isEmpty) {
      return WorkCodeValidationResult.failure('Inserisci il codice aziendale.');
    }
    if (!looksLikeWorkCode(code)) {
      return WorkCodeValidationResult.failure(
        'Formato non valido. Usa CP-XXXXXX-COL o CP-XXXXXX-SUP.',
      );
    }

    try {
      final workData = await _resolveWorkCodeData(code);
      if (workData == null) {
        return WorkCodeValidationResult.failure('Codice non valido o non attivo.');
      }

      final companyId = asString(workData['companyId']);
      final companyCode = asString(workData['companyCode']);
      var companyName = asString(workData['companyName']);
      final normalizedRole = normalizeRoleValue(workData['role']);

      if (companyId.isEmpty || companyCode.isEmpty || normalizedRole.isEmpty) {
        return WorkCodeValidationResult.failure(
          'Codice trovato ma incompleto nei dati azienda.',
        );
      }

      if (companyName.isEmpty) {
        companyName = await _fetchCompanyName(companyId);
      }
      if (companyName.isEmpty && companyCode.isNotEmpty) {
        companyName = companyCode;
      }

      return WorkCodeValidationResult.success(
        context: WorkCompanyLinkContext(
          workCode: code,
          companyId: companyId,
          companyCode: companyCode,
          companyName: companyName,
          workRole: normalizedRole,
        ),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return WorkCodeValidationResult.failure(
          'Permessi insufficienti per leggere i codici aziendali.',
        );
      }
      return WorkCodeValidationResult.failure(
        'Errore di connessione. Riprova.',
      );
    } on TimeoutException {
      return WorkCodeValidationResult.failure(
        'Tempo di attesa superato. Controlla la connessione.',
      );
    } catch (e, st) {
      debugPrint('WorkCodeService: $e\n$st');
      return WorkCodeValidationResult.failure(
        'Errore di connessione. Riprova.',
      );
    }
  }

  static Future<Map<String, dynamic>?> _resolveWorkCodeData(String code) async {
    final direct = await _getWorkCodeDoc(code);
    if (direct != null) return direct;

    final parts = code.split('-');
    if (parts.length < 3) return null;

    final roleSuffix = parts.last.toUpperCase();
    final role = roleSuffix == 'SUP' ? 'supervisor' : 'collaborator';
    final companyCodeWithPrefix = parts.sublist(0, parts.length - 1).join('-');
    final companyCodeNoPrefix = parts.length >= 3 ? parts[1] : '';

    final byExactCode = await FirebaseFirestore.instance
        .collection('work_codes')
        .where('code', isEqualTo: code)
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 10));
    if (byExactCode.docs.isNotEmpty) {
      return byExactCode.docs.first.data();
    }

    final codes = [companyCodeWithPrefix, companyCodeNoPrefix]
        .where((v) => v.isNotEmpty)
        .toList();
    if (codes.isEmpty) return null;

    final byCompanyCode = await FirebaseFirestore.instance
        .collection('work_codes')
        .where('companyCode', whereIn: codes)
        .where('role', isEqualTo: role)
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 10));

    if (byCompanyCode.docs.isNotEmpty) {
      return byCompanyCode.docs.first.data();
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _getWorkCodeDoc(String code) async {
    final snap = await FirebaseFirestore.instance
        .collection('work_codes')
        .doc(code)
        .get()
        .timeout(const Duration(seconds: 10));
    return snap.exists ? snap.data() : null;
  }

  static Future<String> _fetchCompanyName(String companyId) async {
    if (companyId.isEmpty) return '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get()
          .timeout(const Duration(seconds: 8));
      if (!snap.exists) return '';
      final data = snap.data() ?? {};
      final name = asString(data['name']);
      if (name.isNotEmpty) return name;
      return asString(data['companyName']);
    } catch (_) {
      return '';
    }
  }
}

final class WorkCodeValidationResult {
  const WorkCodeValidationResult._({
    required this.ok,
    this.errorMessage,
    this.context,
  });

  final bool ok;
  final String? errorMessage;
  final WorkCompanyLinkContext? context;

  factory WorkCodeValidationResult.success({
    required WorkCompanyLinkContext context,
  }) =>
      WorkCodeValidationResult._(ok: true, context: context);

  factory WorkCodeValidationResult.failure(String message) =>
      WorkCodeValidationResult._(ok: false, errorMessage: message);
}
