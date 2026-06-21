import 'package:flutter/material.dart';

import '../subscription/public_usage_service.dart';
import 'section_lock_service.dart';

/// Blocca il contenuto se il piano public ha esaurito il limite della sezione.
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
  PublicUsageCheckResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await SectionLockService.check(widget.sectionKey);
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });

    if (result.warning && result.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message!),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final result = _result!;
    if (!result.allowed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              result.message ??
                  'Funzione non disponibile con il tuo piano attuale. '
                  'Passa a un piano superiore per continuare.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
