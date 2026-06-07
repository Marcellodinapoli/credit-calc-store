import 'app_version_utils.dart';

/// Documento Firestore: `platform_config/credit_calc_desktop`
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

  /// Installer Setup.exe ha priorità sul vecchio ZIP in `windowsDownloadUrl`.
  static String _resolveDownloadUrl(Map<String, dynamic> data) {
    final installer = (data['windowsInstallerUrl'] ?? '').toString().trim();
    if (installer.isNotEmpty) return installer;

    final legacy = (data['windowsDownloadUrl'] ?? '').toString().trim();
    if (legacy.toLowerCase().contains('-setup.exe')) return legacy;

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
