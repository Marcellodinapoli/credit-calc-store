import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Apertura WhatsApp o client email locale (nessun servizio di invio esterno).
abstract final class DebtorContactLauncher {
  DebtorContactLauncher._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool get _isMobileNative =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool looksLikeEmail(String value) =>
      _emailPattern.hasMatch(value.trim());

  static String normalizePhoneForWhatsApp(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00') && digits.length > 2) {
      digits = digits.substring(2);
    }
    return digits;
  }

  static Future<bool> openWhatsApp({
    required String phone,
    required String message,
  }) async {
    final normalized = normalizePhoneForWhatsApp(phone);
    if (normalized.length < 8) return false;

    final text = message.trim();
    final textSuffix =
        text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}';

    final uris = <Uri>[
      if (_isMobileNative)
        Uri.parse(
          'whatsapp://send?phone=$normalized'
          '${text.isEmpty ? '' : '&text=${Uri.encodeComponent(text)}'}',
        ),
      Uri.parse('https://wa.me/$normalized$textSuffix'),
    ];

    for (final uri in uris) {
      if (await _tryLaunch(uri, external: true)) return true;
    }
    return false;
  }

  static Future<bool> openEmail({
    required String email,
    required String subject,
    required String body,
  }) async {
    final address = email.trim();
    if (!looksLikeEmail(address)) return false;

    final uri = Uri(
      scheme: 'mailto',
      path: address,
      query: _encodeQuery({
        if (subject.trim().isNotEmpty) 'subject': subject.trim(),
        if (body.trim().isNotEmpty) 'body': body.trim(),
      }),
    );

    return _tryLaunch(uri, external: !kIsWeb);
  }

  static Future<bool> _tryLaunch(Uri uri, {required bool external}) async {
    try {
      final mode = external
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault;
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: mode);
      }
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }

  static String? _encodeQuery(Map<String, String> params) {
    if (params.isEmpty) return null;
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
  }
}
