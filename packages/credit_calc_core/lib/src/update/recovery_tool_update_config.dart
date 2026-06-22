import 'package:flutter/foundation.dart';

import 'app_version_utils.dart';

/// Documento Firestore: `platform_config/credit_calc_desktop`
/// Desktop: `windowsInstallerUrl` / `windowsDownloadUrl`
/// Mobile: `androidDownloadUrl`, `iosDownloadUrl`
abstract final class RecoveryToolUpdateConfig {
  static const firestorePath = 'platform_config/credit_calc_desktop';

  static RecoveryToolUpdateInfo? fromFirestoreData(
    Map<String, dynamic>? data, {
    required String installedVersion,
  }) {
    if (data == null) return null;

    final enabled = data['enabled'] as bool? ?? true;
    if (!enabled) return null;

    final remoteVersion = (data['version'] ?? '').toString().trim();
    final downloadUrl = _resolveDownloadUrl(data);
    if (remoteVersion.isEmpty || downloadUrl.isEmpty) return null;

    if (!AppVersionUtils.isNewer(remoteVersion, installedVersion)) {
      return null;
    }

    final notes = (data['releaseNotes'] ?? '').toString().trim();

    return RecoveryToolUpdateInfo(
      installedVersion: installedVersion,
      remoteVersion: remoteVersion,
      downloadUrl: downloadUrl,
      releaseNotes: notes.isEmpty ? null : notes,
    );
  }

  /// URL di download/store in base alla piattaforma corrente.
  static String _resolveDownloadUrl(Map<String, dynamic> data) {
    if (!kIsWeb) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = (data['androidDownloadUrl'] ?? '').toString().trim();
          if (android.isNotEmpty) return android;
        case TargetPlatform.iOS:
          final ios = (data['iosDownloadUrl'] ?? '').toString().trim();
          if (ios.isNotEmpty) return ios;
        case TargetPlatform.macOS:
          final mac = (data['macDownloadUrl'] ?? '').toString().trim();
          if (mac.isNotEmpty) return mac;
        case TargetPlatform.linux:
          final linux = (data['linuxDownloadUrl'] ?? '').toString().trim();
          if (linux.isNotEmpty) return linux;
        default:
          break;
      }
    }

    final installer = (data['windowsInstallerUrl'] ?? '').toString().trim();
    if (installer.isNotEmpty) return installer;

    final legacy = (data['windowsDownloadUrl'] ?? '').toString().trim();
    if (legacy.toLowerCase().contains('-setup.exe')) return legacy;

    final generic = (data['downloadUrl'] ?? '').toString().trim();
    if (generic.isNotEmpty) return generic;

    return legacy;
  }
}

class RecoveryToolUpdateInfo {
  final String installedVersion;
  final String remoteVersion;
  final String downloadUrl;
  final String? releaseNotes;

  const RecoveryToolUpdateInfo({
    required this.installedVersion,
    required this.remoteVersion,
    required this.downloadUrl,
    this.releaseNotes,
  });
}
