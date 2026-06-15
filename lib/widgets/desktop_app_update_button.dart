import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pulsante «Aggiorna» per OTA desktop (Firestore `platform_config/credit_calc_desktop`).
class DesktopAppUpdateButton extends StatefulWidget {
  final bool compact;

  const DesktopAppUpdateButton({super.key, this.compact = false});

  static final packageInfoFuture = PackageInfo.fromPlatform();

  @override
  State<DesktopAppUpdateButton> createState() => _DesktopAppUpdateButtonState();
}

class _DesktopAppUpdateButtonState extends State<DesktopAppUpdateButton> {
  bool _downloading = false;

  static bool get _enabled {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  Future<void> _startDownload(RecoveryToolUpdateInfo info) async {
    final uri = Uri.tryParse(info.downloadUrl);
    if (uri == null) return;

    setState(() => _downloading = true);
    try {
      await _recordDownload();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _downloading = false);

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il link di download')),
      );
    }
  }

  Future<void> _recordDownload() async {
    final docRef =
        FirebaseFirestore.instance.doc(RecoveryToolUpdateConfig.firestorePath);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final current = data['downloadCount'];
      final count = current is int
          ? current
          : current is num
              ? current.toInt()
              : int.tryParse(current?.toString() ?? '') ?? 0;
      tx.update(docRef, {'downloadCount': count + 1});
    });
  }

  Future<void> _confirmAndDownload(RecoveryToolUpdateInfo info) async {
    final notes = info.releaseNotes;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aggiorna a v${info.remoteVersion}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'È disponibile una nuova versione di CreditCalc '
                '(installata: v${info.installedVersion}).',
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  notes,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Più tardi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Scarica'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await _startDownload(info);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .doc(RecoveryToolUpdateConfig.firestorePath)
          .snapshots(),
      builder: (context, snap) {
        return FutureBuilder<PackageInfo>(
          future: DesktopAppUpdateButton.packageInfoFuture,
          builder: (context, pkgSnap) {
            final installed = pkgSnap.data?.version ?? '0.0.0';
            final info = RecoveryToolUpdateConfig.fromFirestoreData(
              snap.data?.data(),
              installedVersion: installed,
            );
            if (info == null) return const SizedBox.shrink();

            final label = widget.compact
                ? 'Aggiorna'
                : 'Aggiorna v${info.remoteVersion}';

            return FilledButton.icon(
              onPressed:
                  _downloading ? null : () => _confirmAndDownload(info),
              style: FilledButton.styleFrom(
                backgroundColor: ProjectColors.calc,
                foregroundColor: Colors.white,
                padding: widget.compact
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: widget.compact ? const Size(0, 32) : null,
                visualDensity: VisualDensity.compact,
              ),
              icon: _downloading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    )
                  : Icon(
                      Icons.system_update_alt,
                      size: widget.compact ? 16 : 18,
                    ),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: widget.compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Versione installata + pulsante aggiornamento in fondo alla shell desktop.
class DesktopAppVersionFooter extends StatelessWidget {
  const DesktopAppVersionFooter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: DesktopAppUpdateButton.packageInfoFuture,
      builder: (context, snap) {
        final version = snap.data?.version ?? '…';
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              const DesktopAppUpdateButton(),
              const Spacer(),
              Text(
                'v$version',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      },
    );
  }
}
