import 'dart:async';

import 'package:flutter/material.dart';

import 'section_lock_config.dart';
import 'section_lock_service.dart';
import 'section_occupancy_result.dart';

/// Mostra un messaggio se la sezione è in uso su un altro dispositivo.
/// Il resto dell'app resta accessibile.
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
  SectionOccupancyResult? _result;
  bool _loading = true;
  bool _ownsSection = false;
  Timer? _heartbeat;
  StreamSubscription<SectionOccupancyResult>? _watchSub;

  @override
  void initState() {
    super.initState();
    _load();
    _watchSub = SectionLockService.watch(widget.sectionKey).listen(
      _onRemoteChange,
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _watchSub?.cancel();
    if (_ownsSection) {
      unawaited(SectionLockService.release(widget.sectionKey));
    }
    super.dispose();
  }

  void _onRemoteChange(SectionOccupancyResult remote) {
    if (!mounted || _loading) return;

    if (!remote.allowed) {
      if (_ownsSection) {
        _ownsSection = false;
        _heartbeat?.cancel();
      }
      setState(() => _result = remote);
      return;
    }

    if (!_ownsSection && _result != null && !_result!.allowed) {
      setState(() => _result = remote);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    SectionOccupancyResult result;
    try {
      result = await SectionLockService.tryAcquire(widget.sectionKey);
    } catch (_) {
      result = SectionOccupancyResult.allowedFree;
    }

    if (!mounted) return;

    if (result.allowed) {
      _ownsSection = true;
      _startHeartbeat();
    } else {
      _ownsSection = false;
      _heartbeat?.cancel();
    }

    setState(() {
      _result = result;
      _loading = false;
    });
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      const Duration(seconds: 30),
      (_) => SectionLockService.touch(widget.sectionKey),
    );
  }

  Future<void> _retry() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final result = _result!;
    if (!result.allowed) {
      final title =
          SectionLockConfig.titleFor(widget.sectionKey) ?? 'Sezione in uso';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  result.message ??
                      'Questa sezione è in uso su un altro dispositivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
