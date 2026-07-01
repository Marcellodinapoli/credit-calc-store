import 'package:flutter/material.dart';

abstract final class _RegistrationCompanyCodeTheme {
  static const accent = Color(0xFF0A66C2);
}

/// Codice aziendale opzionale prima della scelta piano (registrazione store).
class RegistrationCompanyCodeField extends StatelessWidget {
  const RegistrationCompanyCodeField({
    super.key,
    required this.controller,
    required this.validating,
    required this.linked,
    this.linkedCompanyName,
    this.errorText,
    required this.onValidate,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool validating;
  final bool linked;
  final String? linkedCompanyName;
  final String? errorText;
  final VoidCallback onValidate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Codice aziendale',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            linked
                ? 'Account collegato al piano aziendale. Piano individuale e '
                    'coupon non sono necessari.'
                : 'Se la tua azienda ti ha fornito un codice (CP-XXXXXX-COL), '
                    'inseriscilo per usare il piano aziendale.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
          ),
          if (linked && linkedCompanyName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.business_outlined, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Collegato a $linkedCompanyName',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !linked && !validating,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'CP-XXXXXX-COL',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!linked && !validating) onValidate();
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (linked)
                OutlinedButton(
                  onPressed: validating ? null : onClear,
                  child: const Text('Rimuovi'),
                )
              else
                FilledButton(
                  onPressed: validating ? null : onValidate,
                  style: FilledButton.styleFrom(
                    backgroundColor: _RegistrationCompanyCodeTheme.accent,
                  ),
                  child: validating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verifica'),
                ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
