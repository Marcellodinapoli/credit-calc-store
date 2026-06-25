import 'package:flutter/material.dart';

import '../core/theme/project_colors.dart';
import 'limits_reset_coupon_service.dart';

/// Sezione «Coupon limiti» per I miei dati (web e app).
class LimitsResetCouponSection extends StatefulWidget {
  const LimitsResetCouponSection({super.key});

  @override
  State<LimitsResetCouponSection> createState() =>
      _LimitsResetCouponSectionState();
}

class _LimitsResetCouponSectionState extends State<LimitsResetCouponSection> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });

    final result = await LimitsResetCouponService.redeem(_controller.text);

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.success) {
        _success = result.message;
        _controller.clear();
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Azzera i limiti mensili',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Inserisci un coupon creato dal backoffice per azzerare quiz, '
              'warm-up, roleplay, piani di rientro e le altre voci con '
              'limite mensile del piano corrente.',
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.45,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            if (compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Codice coupon',
                      hintText: 'Es. RESET-LIMITI-2026',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _busy ? null : _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: ProjectColors.area,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Applica coupon'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Codice coupon',
                        hintText: 'Es. RESET-LIMITI-2026',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _busy ? null : _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: ProjectColors.area,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Applica'),
                  ),
                ],
              ),
            if (_success != null) ...[
              const SizedBox(height: 10),
              Text(
                _success!,
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
