import 'package:flutter/material.dart';

import '../../core/admin/warmup_contestation_admin_service.dart';
import '../../models/warmup_contestation.dart';
import '../area/personal_area_shell.dart';

/// Backoffice — crea o modifica contestazioni warm-up con schede AI.
class BkWarmupContestationFormPage extends StatefulWidget {
  const BkWarmupContestationFormPage({
    super.key,
    this.existing,
    this.initialContext = WarmupContestationContext.sollecito,
  });

  final WarmupContestation? existing;
  final WarmupContestationContext initialContext;

  @override
  State<BkWarmupContestationFormPage> createState() =>
      _BkWarmupContestationFormPageState();
}

class _BkWarmupContestationFormPageState
    extends State<BkWarmupContestationFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _declaredCtrl;
  late WarmupContestationContext _context;
  late WarmupContestationStatus _status;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _declaredCtrl = TextEditingController(text: existing?.declared ?? '');
    _context = existing?.context ?? widget.initialContext;
    _status = existing?.status ?? WarmupContestationStatus.approved;
  }

  @override
  void dispose() {
    _declaredCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await WarmupContestationAdminService.save(
        id: widget.existing?.id,
        context: _context,
        declared: _declaredCtrl.text.trim(),
        status: _status,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('StateError: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final hasAiSheets = existing != null &&
        existing.meaning.trim().isNotEmpty &&
        existing.risk.trim().isNotEmpty &&
        existing.objective.trim().isNotEmpty &&
        existing.response.trim().isNotEmpty;

    return PersonalAreaShell(
      pageTitle: _isEdit ? 'Modifica contestazione' : 'Nuova contestazione',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
          children: [
            Text(
              'Le schede di analisi (punti 2–5) vengono generate '
              'automaticamente dall\'AI al salvataggio.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<WarmupContestationContext>(
              value: _context,
              decoration: const InputDecoration(
                labelText: 'Contesto',
                border: OutlineInputBorder(),
              ),
              items: WarmupContestationContext.values
                  .map(
                    (ctx) => DropdownMenuItem(
                      value: ctx,
                      child: Text(ctx.label),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _context = value);
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WarmupContestationStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Stato',
                border: OutlineInputBorder(),
              ),
              items: const [
                WarmupContestationStatus.approved,
                WarmupContestationStatus.pendingReview,
                WarmupContestationStatus.draft,
              ]
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _declaredCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Contestazione dichiarata',
                hintText: '«Testo che il cliente dice al telefono»',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Campo obbligatorio';
                }
                return null;
              },
            ),
            if (hasAiSheets) ...[
              const SizedBox(height: 20),
              _readOnlySheet('2. Cosa comunica davvero', existing.meaning),
              const SizedBox(height: 12),
              _readOnlySheet('3. Rischio se gestita male', existing.risk),
              const SizedBox(height: 12),
              _readOnlySheet('4. Obiettivo operatore', existing.objective),
              const SizedBox(height: 12),
              _readOnlySheet(
                '5. Linea di risposta corretta',
                existing.response,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Salva e rigenera schede' : 'Crea con AI'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlySheet(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      child: Text(
        value.trim(),
        style: const TextStyle(height: 1.45),
      ),
    );
  }
}
