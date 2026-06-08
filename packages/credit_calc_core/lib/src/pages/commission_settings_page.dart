import 'package:flutter/material.dart';

import 'commission_creditor_data_access.dart';
import '../core/theme/app_action_styles.dart';
import '../core/theme/app_card_theme.dart';
import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';

import 'commission_payment_resolver.dart';

class CommissionCreditorPicker {
  CommissionCreditorPicker._();

  static String creditorLabel(
    int index,
    Map<String, dynamic> data,
  ) =>
      creditorDisplayLabel(index, data);

  static Future<CreditorPick?> _pickFromDialog(
    BuildContext context, {
    String tileSubtitle = 'Imposta provvigioni',
  }) async {
    final creditors =
        await CommissionCreditorDataAccess.instance.listCreditorsForPicker();
    if (!context.mounted) return null;

    if (creditors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nessun creditore registrato. Aggiungine uno da Creditori '
            'prima di impostare le provvigioni.',
          ),
        ),
      );
      return null;
    }

    return showDialog<CreditorPick>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Creditori registrati'),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Totale creditori: ${creditors.length}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: creditors.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final pick = creditors[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(pick.name),
                          subtitle: Text(tileSubtitle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(ctx, pick),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: AppActionStyles.cancelText,
              child: const Text('Annulla'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> openSettings(BuildContext context) async {
    final selected = await _pickFromDialog(context);
    if (selected == null || !context.mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CommissionSettingsPage(
          creditorId: selected.id,
          creditorName: selected.name,
        ),
      ),
    );

    if (!context.mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provvigioni salvate.')),
      );
    } else if (saved == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modifiche annullate.')),
      );
    }
  }

  static Future<CreditorPick?> pickCreditor(
    BuildContext context, {
    String tileSubtitle = 'Imposta provvigioni',
  }) async {
    return _pickFromDialog(context, tileSubtitle: tileSubtitle);
  }
}

class _CommissionMode {
  final String key;
  final String label;

  const _CommissionMode(this.key, this.label);
}

class _CommissionModeState {
  final TextEditingController rateCtrl;

  _CommissionModeState({String rate = ''})
      : rateCtrl = TextEditingController(text: rate);

  void dispose() => rateCtrl.dispose();
}

class CommissionSettingsPage extends StatefulWidget {
  final String creditorId;
  final String creditorName;

  const CommissionSettingsPage({
    super.key,
    required this.creditorId,
    required this.creditorName,
  });

  @override
  State<CommissionSettingsPage> createState() => _CommissionSettingsPageState();
}

class _CommissionSettingsPageState extends State<CommissionSettingsPage> {
  static const _modes = [
    _CommissionMode('contanti', 'Contanti'),
    _CommissionMode('bollettinoPostale', 'Bollettino postale'),
    _CommissionMode('assegnoBancario', 'Assegno bancario'),
    _CommissionMode('bonificoBancarioPostale', 'Bonifico bancario/postale'),
    _CommissionMode('vagliaOrdinaria', 'Vaglia ordinaria (Vo)'),
    _CommissionMode('pdrEffettiCambiari', 'Pdr c/effetti cambiari'),
    _CommissionMode('pdrBollettiniPostali', 'Pdr c/bollettini postali'),
  ];

  late String _creditorId;
  late String _creditorName;
  late Map<String, _CommissionModeState> _rows;
  Map<String, bool> _allowedMethods = {};
  Map<String, String> _initialRates = {};
  bool _loading = true;
  bool _saving = false;

  static const _primaryBlue = Color(0xFF0A66C2);

  Map<String, String> _currentRatesSnapshot() {
    return {
      for (final mode in _modes) mode.key: _rows[mode.key]!.rateCtrl.text.trim(),
    };
  }

  void _captureInitialSnapshot() {
    _initialRates = _currentRatesSnapshot();
  }

  bool get _hasUnsavedChanges {
    final current = _currentRatesSnapshot();
    for (final mode in _modes) {
      if ((current[mode.key] ?? '') != (_initialRates[mode.key] ?? '')) {
        return true;
      }
    }
    return false;
  }

  bool get _canSave => !_saving && !_loading && _hasUnsavedChanges;

  @override
  void initState() {
    super.initState();
    _creditorId = widget.creditorId;
    _creditorName = widget.creditorName;
    _rows = {
      for (final mode in _modes) mode.key: _CommissionModeState(),
    };
    _loadSettings();
  }

  @override
  void dispose() {
    for (final row in _rows.values) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final data = await CommissionCreditorDataAccess.instance
              .loadCreditor(_creditorId) ??
          {};
      final settings =
          (data['commissionSettings'] as Map<String, dynamic>?) ?? {};

      _allowedMethods = CommissionPaymentResolver.allowedMethods(data);

      for (final mode in _modes) {
        _rows[mode.key]!.dispose();
        final allowed = _allowedMethods[mode.key] == true;
        final saved = settings[mode.key];
        final rate = allowed && saved is Map<String, dynamic>
            ? (saved['rate'] ?? '').toString()
            : '';
        _rows[mode.key] = _CommissionModeState(rate: rate);
      }
    } catch (_) {
      // Mantieni valori di default.
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _captureInitialSnapshot();
        });
      }
    }
  }

  Future<void> _changeCreditor() async {
    final picked = await CommissionCreditorPicker.pickCreditor(context);
    if (picked == null || !mounted) return;
    if (picked.id == _creditorId) return;

    for (final row in _rows.values) {
      row.dispose();
    }
    setState(() {
      _creditorId = picked.id;
      _creditorName = picked.name;
      _rows = {
        for (final mode in _modes) mode.key: _CommissionModeState(),
      };
    });
    await _loadSettings();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = {
        for (final mode in _modes)
          mode.key: {
            'enabled': _allowedMethods[mode.key] == true,
            'rate': _allowedMethods[mode.key] == true
                ? _rows[mode.key]!.rateCtrl.text.trim()
                : '',
          },
      };

      await CommissionCreditorDataAccess.instance.saveCommissionSettings(
        creditorId: _creditorId,
        commissionSettings: payload,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante il salvataggio.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelChanges() {
    Navigator.of(context).pop(false);
  }

  void _clearRow(String key) {
    setState(() => _rows[key]!.rateCtrl.clear());
  }

  int get _allowedCount => CommissionPaymentResolver.countAllowed(_allowedMethods);

  Widget _creditorHeader() {
    return Card(
      color: AppCardTheme.surface,
      elevation: AppCardTheme.elevation,
      shape: AppCardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _primaryBlue.withValues(alpha: 0.12),
              child: const Icon(Icons.account_balance, color: _primaryBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _creditorName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_allowedCount di ${_modes.length} modalità previste '
                    'nella scheda creditore',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _changeCreditor,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Cambia'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryBlue,
                side: const BorderSide(color: _primaryBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendChip({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
      ],
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 36),
          Expanded(
            flex: 5,
            child: Text(
              'Modalità di pagamento',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Provvigione %',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _modeRow(_CommissionMode mode, {required bool isLast}) {
    final allowed = _allowedMethods[mode.key] == true;
    final row = _rows[mode.key]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: allowed ? Colors.white : Colors.grey.shade50,
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            allowed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: allowed ? Colors.green.shade600 : Colors.red.shade400,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: allowed ? Colors.black87 : Colors.black45,
                  ),
                ),
                if (!allowed) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Non prevista nella scheda creditore',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: row.rateCtrl,
                    enabled: allowed,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    onChanged: allowed ? (_) => setState(() {}) : null,
                    style: TextStyle(
                      color: allowed ? Colors.black87 : Colors.black38,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: allowed ? Colors.white : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: allowed ? Colors.black87 : Colors.black38,
                  ),
                ),
                if (allowed)
                  IconButton(
                    onPressed: row.rateCtrl.text.trim().isEmpty
                        ? null
                        : () => _clearRow(mode.key),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.shade700,
                    tooltip: 'Azzera provvigione',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  )
                else
                  const SizedBox(width: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modesTable() {
    return Card(
      elevation: AppCardTheme.elevation,
      shape: AppCardTheme.shape,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _tableHeader(),
          ...List.generate(_modes.length, (index) {
            return _modeRow(
              _modes[index],
              isLast: index == _modes.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Card(
      color: Colors.white,
      elevation: AppCardTheme.elevation,
      shape: AppCardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _cancelChanges,
                icon: const Icon(
                  Icons.refresh,
                  color: AppActionStyles.cancelForeground,
                ),
                label: const Text(
                  'Annulla modifiche',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: AppActionStyles.cancelOutlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _canSave ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, color: Colors.white),
                label: Text(
                  _saving ? 'Salvataggio...' : 'Salva provvigioni',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'Impostazioni provvigioni',
      current: CreditCalcNavItem.commissions,
      body: ColoredBox(
        color: const Color(0xFFE8E8E8),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _creditorHeader(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _legendChip(
                      icon: Icons.check_circle_rounded,
                      color: Colors.green.shade600,
                      label: 'Prevista — provvigione compilabile',
                    ),
                    _legendChip(
                      icon: Icons.cancel_rounded,
                      color: Colors.red.shade400,
                      label: 'Non prevista — campo bloccato',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _modesTable(),
                if (_allowedCount == 0) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.orange.shade50,
                    shape: AppCardTheme.shape,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Nessuna modalità risulta configurata nella scheda '
                              'di questo creditore. Apri Impostazioni creditori e '
                              'compila le coordinate o seleziona le modalità PDR.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _actionBar(),
              ],
            ),
      ),
    );
  }
}
