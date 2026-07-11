import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/warmup_contestation.dart';
import '../../services/warmup_contestation_service.dart';
import 'personal_form_shell.dart';

/// Creazione o modifica di una contestazione personale warm-up.
class UserContestationFormPage extends StatefulWidget {
  const UserContestationFormPage({
    super.key,
    required this.context,
    this.existing,
  });

  final WarmupContestationContext context;
  final WarmupContestation? existing;

  @override
  State<UserContestationFormPage> createState() =>
      _UserContestationFormPageState();
}

class _UserContestationFormPageState extends State<UserContestationFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _declaredCtrl;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final declared = e?.declared.trim().isNotEmpty == true
        ? e!.declared
        : (e?.userRawInput ?? '');
    _declaredCtrl = TextEditingController(text: declared);
  }

  @override
  void dispose() {
    _declaredCtrl.dispose();
    super.dispose();
  }

  String _autoTitle(String declared) {
    final text = declared.trim();
    if (text.length <= 48) return text;
    return '${text.substring(0, 45)}…';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final displayName = user?.displayName;
      final declared = _declaredCtrl.text.trim();
      final title = _autoTitle(declared);
      final existing = widget.existing;

      final declaredChanged = existing != null &&
          declared != existing.declared.trim();
      final needsAi = existing == null ||
          declaredChanged ||
          (existing != null &&
              !WarmupContestationService.hasCompleteSheets(existing));

      late final String meaning;
      late final String risk;
      late final String objective;
      late final String response;
      late final WarmupContestationCategory category;

      if (needsAi) {
        final generated = await WarmupContestationService.generateSheets(
          declared: declared,
          context: widget.context,
        );
        meaning = generated.meaning;
        risk = generated.risk;
        objective = generated.objective;
        response = generated.response;
        category = generated.category;
      } else {
        meaning = existing.meaning;
        risk = existing.risk;
        objective = existing.objective;
        response = existing.response;
        category = existing.category;
      }

      if (_isEdit) {
        await WarmupContestationService.update(
          id: existing!.id,
          title: title,
          declared: declared,
          meaning: meaning,
          risk: risk,
          objective: objective,
          response: response,
          category: category,
          status: WarmupContestationStatus.pendingReview,
        );
      } else {
        await WarmupContestationService.create(
          context: widget.context,
          title: title,
          declared: declared,
          meaning: meaning,
          risk: risk,
          objective: objective,
          response: response,
          userRawInput: declared,
          category: category,
          status: WarmupContestationStatus.pendingReview,
          authorName: displayName,
        );
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_isEdit ? 'Contestazione aggiornata' : 'Contestazione inviata'),
          content: const Text(
            'La contestazione è già visibile nel tuo elenco e puoi usarla per '
            'allenarti. Per la condivisione con tutti gli utenti è necessario '
            'attendere l\'approvazione dello staff.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
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
    final ctxLabel = widget.context.label;
    final existing = widget.existing;
    final hasAiSheets =
        existing != null && WarmupContestationService.hasCompleteSheets(existing);

    return PersonalFormShell(
      pageTitle: _isEdit ? 'Modifica contestazione' : 'Nuova contestazione',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Contestazione nel contesto: $ctxLabel',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            _field(
              _declaredCtrl,
              'Contestazione dichiarata',
              '«Testo che il cliente dice al telefono»',
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            Text(
              'Schede di analisi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAiSheets
                  ? 'Le schede sotto sono state generate automaticamente dall\'AI.'
                  : 'Le schede di analisi (punti 2–5) verranno compilate '
                      'automaticamente dall\'AI dopo l\'invio.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (hasAiSheets) ...[
              const SizedBox(height: 12),
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
                  : Text(
                      _isEdit
                          ? 'Salva modifiche'
                          : 'Invia e genera schede',
                    ),
            ),
            if (_isEdit && existing!.canDelete) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _saving ? null : _confirmDelete,
                icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                label: Text(
                  'Elimina',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Campo obbligatorio';
        }
        return null;
      },
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

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina contestazione'),
        content: const Text(
          'Vuoi eliminare definitivamente questa contestazione?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await WarmupContestationService.delete(widget.existing!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('StateError: ', '');
      });
    }
  }
}
