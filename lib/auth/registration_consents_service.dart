import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_redirect_feedback.dart';
import 'registration_privacy_consents_page.dart';

class RegistrationConsentsDocument {
  const RegistrationConsentsDocument({
    required this.version,
    required this.text,
  });

  final String version;
  final String text;
}

class RegistrationConsentsService {
  RegistrationConsentsService._();

  static const settingsDocId = 'registration_consents';
  static const userVersionField = 'registrationConsentsAcceptedVersion';
  static const userAcceptedAtField = 'registrationConsentsAcceptedAt';
  static const _loadTimeout = Duration(seconds: 20);

  static Future<RegistrationConsentsDocument?> loadCurrent() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final rulesDoc = await firestore
          .collection('settings')
          .doc(settingsDocId)
          .get()
          .timeout(_loadTimeout);

      if (!rulesDoc.exists) return null;

      final data = rulesDoc.data() ?? {};
      final version = (data['version'] ?? '1.0.0').toString();

      final versionDoc = await firestore
          .collection('settings')
          .doc(settingsDocId)
          .collection('versions')
          .doc(version)
          .get()
          .timeout(_loadTimeout);

      final versionData = versionDoc.data();
      final text = (versionData?['text'] ?? data['text'] ?? '').toString();

      if (text.isEmpty) return null;

      return RegistrationConsentsDocument(version: version, text: text);
    } on TimeoutException catch (e, stack) {
      debugPrint('RegistrationConsentsService.loadCurrent timeout: $e\n$stack');
      return null;
    } catch (e, stack) {
      debugPrint('RegistrationConsentsService.loadCurrent failed: $e\n$stack');
      return null;
    }
  }

  static Future<String?> getAcceptedVersion({
    required String uid,
    required bool isCompany,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final doc = await (isCompany
            ? firestore.collection('companies').doc(uid)
            : firestore.collection('users').doc(uid))
        .get();

    if (!doc.exists) return null;

    final value = doc.data()?[userVersionField];
    if (value == null) return null;
    return value.toString();
  }

  static Future<void> saveAcceptance({
    required String uid,
    required String version,
    required String source,
    required bool isCompany,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final acceptedAt = FieldValue.serverTimestamp();
    final historyPayload = {
      'type': 'registration_consents',
      'version': version,
      'acceptedAt': acceptedAt,
      'source': source,
    };

    if (isCompany) {
      final companyRef = firestore.collection('companies').doc(uid);
      await companyRef.update({
        userVersionField: version,
        userAcceptedAtField: acceptedAt,
      });
      await companyRef
          .collection('registration_consents_history')
          .doc(version)
          .set(historyPayload);
      return;
    }

    final userRef = firestore.collection('users').doc(uid);
    await userRef.update({
      userVersionField: version,
      userAcceptedAtField: acceptedAt,
    });
    await userRef.collection('consents_history').doc(version).set(historyPayload);
    await userRef.collection('consents_history').doc('privacy_registration').set({
      'type': 'privacy_and_consents',
      'version': version,
      'acceptedAt': acceptedAt,
      'source': source,
    });
  }

  static Future<bool> ensureAcceptedOnLogin(
    BuildContext context, {
    required String uid,
    required bool isCompany,
  }) async {
    final current = await loadCurrent();
    if (current == null) return true;

    final accepted = await getAcceptedVersion(uid: uid, isCompany: isCompany);
    if (accepted == current.version) return true;

    if (!context.mounted) return false;

    final version = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrationPrivacyConsentsPage(
          text: current.text,
          version: current.version,
          mandatory: true,
        ),
      ),
    );

    if (version == null) {
      AuthRedirectFeedback.setMessage(
        'Per accedere devi accettare l\'informativa privacy e consensi aggiornata.',
      );
      await FirebaseAuth.instance.signOut();
      return false;
    }

    await saveAcceptance(
      uid: uid,
      version: version,
      source: 'login',
      isCompany: isCompany,
    );
    return true;
  }
}
