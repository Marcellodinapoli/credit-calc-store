import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import '../../offline/credit_calc_repository_setup.dart';
import '../../offline/services/sync_engine.dart';

class CreditCalcInitialSyncPage extends StatefulWidget {
  final SyncEngine syncEngine;
  final VoidCallback onComplete;

  const CreditCalcInitialSyncPage({
    super.key,
    required this.syncEngine,
    required this.onComplete,
  });

  @override
  State<CreditCalcInitialSyncPage> createState() =>
      _CreditCalcInitialSyncPageState();
}

class _CreditCalcInitialSyncPageState extends State<CreditCalcInitialSyncPage> {
  String _step = 'Preparazione…';
  double _progress = 0;
  String? _error;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await widget.syncEngine.performInitialSync(
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _step = p.step;
            _progress = p.progress;
          });
        },
      );
      CreditCalcRepositorySetup.notifyDataChanged();
      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('StateError: ', '');
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sincronizzazione iniziale',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error ??
                        'Scarichiamo creditori, pratiche e configurazioni da Firebase.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _error != null ? Colors.red.shade700 : Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_error == null) ...[
                    LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                    const SizedBox(height: 12),
                    Text(_step, style: TextStyle(color: Colors.grey.shade700)),
                  ] else ...[
                    FilledButton(
                      onPressed: _start,
                      style: FilledButton.styleFrom(
                        backgroundColor: ProjectColors.calc,
                      ),
                      child: const Text('Riprova'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
