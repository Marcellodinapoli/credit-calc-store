import 'package:cloud_firestore/cloud_firestore.dart';

class AppDownloadCatalogEntry {
  const AppDownloadCatalogEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.platforms,
    required this.version,
    required this.releaseDate,
    required this.totalDownloads,
    required this.enabled,
  });

  final String id;
  final String title;
  final String description;
  final List<String> platforms;
  final String version;
  final DateTime? releaseDate;
  final int totalDownloads;
  final bool enabled;

  static AppDownloadCatalogEntry fromDefinition({
    required String id,
    required String title,
    required String description,
    Map<String, dynamic>? data,
  }) {
    final map = data ?? {};
    return AppDownloadCatalogEntry(
      id: id,
      title: title,
      description: description,
      platforms: _platforms(map),
      version: _version(map),
      releaseDate: _releaseDate(map),
      totalDownloads: _totalDownloads(map),
      enabled: map['enabled'] as bool? ?? true,
    );
  }

  static String _version(Map<String, dynamic> data) {
    final raw = (data['version'] ?? '').toString().trim();
    if (raw.isEmpty || raw == '—') return '—';
    if (raw.contains(r'\') || (raw.contains('/') && raw.contains('.'))) {
      final parts = raw.split(RegExp(r'[/\\]'));
      return parts.isNotEmpty ? parts.last : raw;
    }
    return raw;
  }

  static DateTime? _releaseDate(Map<String, dynamic> data) {
    for (final key in [
      'releasedAt',
      'lastReleasedAt',
      'releaseDate',
      'updatedAt',
    ]) {
      final raw = data[key];
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
    }
    return null;
  }

  static int _totalDownloads(Map<String, dynamic> data) {
    int read(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return read(data['downloadCount']) + read(data['macDownloadCount']);
  }

  static bool _hasWindowsUrl(Map<String, dynamic> data) {
    final installer = (data['windowsInstallerUrl'] ?? '').toString().trim();
    if (installer.isNotEmpty) return true;
    return (data['windowsDownloadUrl'] ?? '').toString().trim().isNotEmpty;
  }

  static bool _hasMacUrl(Map<String, dynamic> data) {
    final installer = (data['macInstallerUrl'] ?? '').toString().trim();
    if (installer.isNotEmpty) return true;
    return (data['macDownloadUrl'] ?? '').toString().trim().isNotEmpty;
  }

  static List<String> _platforms(Map<String, dynamic> data) {
    final platforms = <String>[];
    if (_hasWindowsUrl(data)) platforms.add('Windows');
    if (_hasMacUrl(data)) platforms.add('macOS');
    platforms.add('Android');
    platforms.add('iOS');
    return platforms;
  }

  String get formattedReleaseDate {
    final date = releaseDate;
    if (date == null) return 'Data non disponibile';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String get formattedDownloads {
    if (totalDownloads == 0) return '0 download';
    if (totalDownloads == 1) return '1 download';
    return '$totalDownloads download';
  }
}
