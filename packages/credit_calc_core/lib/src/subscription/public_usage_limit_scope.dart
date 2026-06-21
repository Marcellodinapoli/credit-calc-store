import 'package:flutter/material.dart';

import '../subscription/public_plan_limits.dart';
import '../subscription/public_usage_service.dart';

/// Blocca la sezione se il limite del piano è già raggiunto (lettura dal server).
class PublicUsageLimitScope extends StatefulWidget {
  const PublicUsageLimitScope({
    super.key,
    required this.metric,
    required this.child,
    this.title,
  });

  final PublicUsageMetric metric;
  final Widget child;
  final String? title;

  @override
  State<PublicUsageLimitScope> createState() => _PublicUsageLimitScopeState();
}

class _PublicUsageLimitScopeState extends State<PublicUsageLimitScope> {
  PublicUsageCheckResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await PublicUsageService.check(
      widget.metric,
      consumeAmount: 1,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final result = _result!;
    if (!result.allowed) {
      final title = widget.title ?? publicUsageMetricLabel(widget.metric);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  'Limite piano raggiunto',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  result.message ??
                      'Hai raggiunto il limite del tuo piano per questa funzione.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _load,
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
