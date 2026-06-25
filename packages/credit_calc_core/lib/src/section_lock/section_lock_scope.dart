import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_card_theme.dart';
import '../core/theme/project_colors.dart';
import 'section_lock_service.dart';

/// Acquisisce il blocco sezione all'apertura e lo rilascia in uscita.
class SectionLockScope extends StatefulWidget {
  const SectionLockScope({
    super.key,
    required this.sectionKey,
    required this.child,
  });

  final String sectionKey;
  final Widget child;

  @override
  State<SectionLockScope> createState() => _SectionLockScopeState();
}

class _SectionLockScopeState extends State<SectionLockScope> {
  bool _loading = true;
  bool _blocked = false;
  DateTime? _lockedAt;
  Timer? _heartbeat;
  StreamSubscription<SectionLockState?>? _watchSub;

  @override
  void initState() {
    super.initState();
    unawaited(_acquire());
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _watchSub?.cancel();
    unawaited(SectionLockService.release(widget.sectionKey));
    super.dispose();
  }

  Future<void> _acquire() async {
    try {
      final result = await SectionLockService.acquire(widget.sectionKey)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;

      switch (result) {
        case SectionLockAcquireResult.acquired:
          _startHeartbeat();
          _watchRemoteLock();
          setState(() {
            _loading = false;
            _blocked = false;
          });
        case SectionLockAcquireResult.blocked:
          await _loadBlockedAt();
          if (!mounted) return;
          _watchRemoteLock();
          setState(() {
            _loading = false;
            _blocked = true;
          });
        case SectionLockAcquireResult.unauthenticated:
          setState(() {
            _loading = false;
            _blocked = false;
          });
      }
    } catch (_) {
      // Fail-open: il blocco sezione non deve impedire l'uso dell'app
      // (es. regole Firestore non deployate o rete instabile).
      if (!mounted) return;
      setState(() {
        _loading = false;
        _blocked = false;
      });
    }
  }

  Future<void> _loadBlockedAt() async {
    try {
      await for (final state in SectionLockService.watch(widget.sectionKey)) {
        if (state != null && state.isBlocked) {
          _lockedAt = state.lockedAt;
        }
        break;
      }
    } catch (_) {}
  }

  void _watchRemoteLock() {
    _watchSub?.cancel();
    _watchSub = SectionLockService.watch(widget.sectionKey).listen((state) {
      if (!mounted || state == null) return;
      if (state.ownedByThisDevice && _blocked) {
        setState(() {
          _blocked = false;
          _loading = false;
        });
        _startHeartbeat();
      } else if (state.isBlocked && !_blocked) {
        setState(() {
          _blocked = true;
          _lockedAt = state.lockedAt;
        });
        _heartbeat?.cancel();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(SectionLockService.touch(widget.sectionKey));
    });
  }

  String _formatLockedAt(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_blocked) {
      return _SectionLockedView(
        lockedAtLabel: _formatLockedAt(_lockedAt),
        onRetry: () {
          setState(() => _loading = true);
          unawaited(_acquire());
        },
      );
    }

    return widget.child;
  }
}

class _SectionLockedView extends StatelessWidget {
  const _SectionLockedView({
    required this.lockedAtLabel,
    required this.onRetry,
  });

  final String lockedAtLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          color: const Color(0xFFFFF7ED),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppCardTheme.radius),
            side: const BorderSide(color: Color(0xFFFDBA74)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_off_outlined, color: Colors.orange.shade800, size: 36),
                const SizedBox(height: 12),
                Text(
                  'Sezione in modifica',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Questa sezione è attualmente in modifica da un altro '
                  'tuo account/device.',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    height: 1.45,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (lockedAtLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Blocco attivo dalle $lockedAtLabel.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.maybePop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ProjectColors.area,
                    side: BorderSide(color: ProjectColors.area.withValues(alpha: 0.5)),
                  ),
                  child: const Text('Torna indietro'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Riprova'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
