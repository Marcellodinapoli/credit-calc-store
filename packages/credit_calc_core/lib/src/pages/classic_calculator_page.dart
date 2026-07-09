import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/credit_calc_page_host.dart';
import '../nav/credit_calc_nav.dart';
import 'balance_write_off_page.dart';
import 'commission_entry_page.dart';
import 'standard_repayment_plan_page.dart';

/// Calcolatrice standard (stile Windows) — memoria, percentuali, √, x², 1/x.
class ClassicCalculatorPage extends StatefulWidget {
  /// Nasconde i collegamenti a piano di rientro, saldo e stralcio e incasso
  /// quando la calcolatrice è aperta da altre sezioni.
  final bool disableHandoffButtons;

  const ClassicCalculatorPage({
    super.key,
    this.disableHandoffButtons = false,
  });

  @override
  State<ClassicCalculatorPage> createState() => _ClassicCalculatorPageState();
}

class _ClassicCalculatorPageState extends State<ClassicCalculatorPage> {
  static const _handoffColor = Color(0xFF0A66C2);

  final _focusNode = FocusNode(debugLabel: 'classicCalculator');

  String _display = '0';
  String? _pendingOp;
  double? _operand1;
  bool _freshEntry = true;
  double _memory = 0;
  bool _hasMemory = false;

  double get _value => _parse(_display);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String? _digitForKey(LogicalKeyboardKey key) => switch (key) {
        LogicalKeyboardKey.digit0 || LogicalKeyboardKey.numpad0 => '0',
        LogicalKeyboardKey.digit1 || LogicalKeyboardKey.numpad1 => '1',
        LogicalKeyboardKey.digit2 || LogicalKeyboardKey.numpad2 => '2',
        LogicalKeyboardKey.digit3 || LogicalKeyboardKey.numpad3 => '3',
        LogicalKeyboardKey.digit4 || LogicalKeyboardKey.numpad4 => '4',
        LogicalKeyboardKey.digit5 || LogicalKeyboardKey.numpad5 => '5',
        LogicalKeyboardKey.digit6 || LogicalKeyboardKey.numpad6 => '6',
        LogicalKeyboardKey.digit7 || LogicalKeyboardKey.numpad7 => '7',
        LogicalKeyboardKey.digit8 || LogicalKeyboardKey.numpad8 => '8',
        LogicalKeyboardKey.digit9 || LogicalKeyboardKey.numpad9 => '9',
        _ => null,
      };

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final digit = _digitForKey(event.logicalKey);
    if (digit != null) {
      _inputDigit(digit);
      _refocusKeyboard();
      return KeyEventResult.handled;
    }

    final key = event.logicalKey;
    final char = event.character;

    if (key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.comma ||
        key == LogicalKeyboardKey.numpadDecimal) {
      _inputDecimal();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.delete) {
      _clearEntry();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      _clearAll();
      return KeyEventResult.handled;
    }

    if (char == '%') {
      _percent();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.numpadAdd || char == '+') {
      _setOperation('+');
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract ||
        char == '-') {
      _setOperation('-');
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.asterisk ||
        key == LogicalKeyboardKey.numpadMultiply ||
        char == '*') {
      _setOperation('×');
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.slash ||
        key == LogicalKeyboardKey.numpadDivide ||
        char == '/') {
      _setOperation('÷');
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.equal ||
        char == '=') {
      _equals();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _refocusKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  VoidCallback _btn(VoidCallback action) => () {
        action();
        _refocusKeyboard();
      };

  double _parse(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  String _format(double value) {
    if (value.isNaN) return 'Errore';
    if (value.isInfinite) {
      return value.isNegative ? '-∞' : '∞';
    }
    if (value.abs() >= 1e12 || (value != 0 && value.abs() < 1e-9)) {
      return value
          .toStringAsExponential(8)
          .replaceAll('.', ',')
          .replaceAll('e', 'E');
    }
    var text = value.toStringAsFixed(12);
    text = text.replaceAll(RegExp(r'0+$'), '');
    text = text.replaceAll(RegExp(r'\.$'), '');
    return text.replaceAll('.', ',');
  }

  void _setDisplay(double value) {
    setState(() => _display = _format(value));
  }

  void _inputDigit(String digit) {
    setState(() {
      if (_freshEntry || _display == '0') {
        _display = digit;
        _freshEntry = false;
      } else if (_display.length < 16) {
        _display += digit;
      }
    });
  }

  void _inputDecimal() {
    setState(() {
      if (_freshEntry) {
        _display = '0,';
        _freshEntry = false;
        return;
      }
      if (!_display.contains(',')) {
        _display += ',';
      }
    });
  }

  void _clearAll() {
    setState(() {
      _display = '0';
      _pendingOp = null;
      _operand1 = null;
      _freshEntry = true;
    });
  }

  void _clearEntry() {
    setState(() {
      _display = '0';
      _freshEntry = true;
    });
  }

  void _backspace() {
    setState(() {
      if (_freshEntry) return;
      if (_display.length <= 1 || (_display.length == 2 && _display.startsWith('-'))) {
        _display = '0';
        _freshEntry = true;
        return;
      }
      _display = _display.substring(0, _display.length - 1);
      if (_display.isEmpty || _display == '-') {
        _display = '0';
        _freshEntry = true;
      }
    });
  }

  void _toggleSign() {
    setState(() {
      if (_display == '0') return;
      if (_display.startsWith('-')) {
        _display = _display.substring(1);
      } else {
        _display = '-$_display';
      }
      _freshEntry = false;
    });
  }

  void _applyUnary(double Function(double) fn) {
    _setDisplay(fn(_value));
    _freshEntry = true;
  }

  void _percent() {
    if (_operand1 != null && _pendingOp != null) {
      _setDisplay(_operand1! * _value / 100);
    } else {
      _setDisplay(_value / 100);
    }
    _freshEntry = true;
  }

  double? _compute(double a, String op, double b) {
    return switch (op) {
      '+' => a + b,
      '-' => a - b,
      '×' => a * b,
      '÷' => b == 0 ? double.nan : a / b,
      _ => null,
    };
  }

  void _setOperation(String op) {
    if (_operand1 != null && _pendingOp != null && !_freshEntry) {
      final result = _compute(_operand1!, _pendingOp!, _value);
      if (result == null) return;
      _operand1 = result;
      _setDisplay(result);
    } else {
      _operand1 = _value;
    }
    setState(() {
      _pendingOp = op;
      _freshEntry = true;
    });
  }

  void _equals() {
    if (_operand1 == null || _pendingOp == null) return;
    final result = _compute(_operand1!, _pendingOp!, _value);
    if (result == null) return;
    setState(() {
      _operand1 = null;
      _pendingOp = null;
      _freshEntry = true;
      _display = _format(result);
    });
  }

  void _memoryClear() {
    setState(() {
      _memory = 0;
      _hasMemory = false;
    });
  }

  void _memoryRecall() {
    _setDisplay(_memory);
    _freshEntry = true;
  }

  void _memoryStore() {
    setState(() {
      _memory = _value;
      _hasMemory = true;
    });
  }

  void _memoryAdd() {
    setState(() {
      _memory += _value;
      _hasMemory = true;
    });
  }

  void _memorySubtract() {
    setState(() {
      _memory -= _value;
      _hasMemory = true;
    });
  }

  void _showMemoryPanel() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Memoria',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                _hasMemory ? _format(_memory) : 'Vuota',
                style: const TextStyle(fontSize: 24),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canHandoff {
    final value = _value;
    return !value.isNaN && !value.isInfinite && value > 0;
  }

  double? _handoffAmount() {
    if (!_canHandoff) return null;
    return _value;
  }

  void _openHandoffPage(Widget Function(double amount) buildPage) {
    final amount = _handoffAmount();
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un importo maggiore di zero sul display.'),
        ),
      );
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => buildPage(amount)),
    );
  }

  void _openRepaymentPlan() {
    _openHandoffPage(
      (amount) => StandardRepaymentPlanPage(
        key: ValueKey('calc-pdr-$amount'),
        initialPrefillAmount: amount,
      ),
    );
  }

  void _openBalanceWriteOff() {
    _openHandoffPage(
      (amount) => BalanceWriteOffPage(
        key: ValueKey('calc-bwo-$amount'),
        initialPrefillAmount: amount,
      ),
    );
  }

  void _openCommissionEntry() {
    _openHandoffPage(
      (amount) => CommissionEntryPage(
        key: ValueKey('calc-comm-$amount'),
        initialAmountCollected: amount,
      ),
    );
  }

  Widget _handoffButtonsRow(double height) {
    final enabled = !widget.disableHandoffButtons && _canHandoff;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          _handoffButton(
            'Sviluppa\npiano di rientro',
            enabled ? _openRepaymentPlan : null,
            height,
          ),
          const SizedBox(width: 4),
          _handoffButton(
            'Sviluppa\nsaldo e stralcio',
            enabled ? _openBalanceWriteOff : null,
            height,
          ),
          const SizedBox(width: 4),
          _handoffButton(
            'Inserisci\nincasso',
            enabled ? _openCommissionEntry : null,
            height,
          ),
        ],
      ),
    );
  }

  Widget _handoffButton(String label, VoidCallback? onTap, double height) {
    final enabled = onTap != null;
    return Expanded(
      child: Material(
        color: enabled ? _handoffColor : _handoffColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _calculatorCard(double buttonHeight) {
    final handoffHeight = buttonHeight + 6;
    return Card(
      elevation: 2,
      color: const Color(0xFFF3F3F3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Standard',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _display,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _memoryRow(),
            _handoffButtonsRow(handoffHeight),
            const SizedBox(height: 8),
            _buttonRow([
              _CalcBtn('%', height: buttonHeight, onTap: _btn(_percent)),
              _CalcBtn('CE', height: buttonHeight, onTap: _btn(_clearEntry)),
              _CalcBtn('C', height: buttonHeight, onTap: _btn(_clearAll)),
              _CalcBtn(
                '⌫',
                height: buttonHeight,
                onTap: _btn(_backspace),
                icon: Icons.backspace_outlined,
              ),
            ]),
            _buttonRow([
              _CalcBtn(
                '¹/x',
                height: buttonHeight,
                onTap: _btn(() => _applyUnary((v) => v == 0 ? double.nan : 1 / v)),
              ),
              _CalcBtn(
                'x²',
                height: buttonHeight,
                onTap: _btn(() => _applyUnary((v) => v * v)),
              ),
              _CalcBtn(
                '²√x',
                height: buttonHeight,
                onTap: _btn(() => _applyUnary((v) => v < 0 ? double.nan : math.sqrt(v))),
              ),
              _CalcBtn(
                '÷',
                height: buttonHeight,
                onTap: _btn(() => _setOperation('÷')),
                accent: true,
              ),
            ]),
            _buttonRow([
              _CalcBtn('7', height: buttonHeight, onTap: _btn(() => _inputDigit('7'))),
              _CalcBtn('8', height: buttonHeight, onTap: _btn(() => _inputDigit('8'))),
              _CalcBtn('9', height: buttonHeight, onTap: _btn(() => _inputDigit('9'))),
              _CalcBtn(
                '×',
                height: buttonHeight,
                onTap: _btn(() => _setOperation('×')),
                accent: true,
              ),
            ]),
            _buttonRow([
              _CalcBtn('4', height: buttonHeight, onTap: _btn(() => _inputDigit('4'))),
              _CalcBtn('5', height: buttonHeight, onTap: _btn(() => _inputDigit('5'))),
              _CalcBtn('6', height: buttonHeight, onTap: _btn(() => _inputDigit('6'))),
              _CalcBtn(
                '−',
                height: buttonHeight,
                onTap: _btn(() => _setOperation('-')),
                accent: true,
              ),
            ]),
            _buttonRow([
              _CalcBtn('1', height: buttonHeight, onTap: _btn(() => _inputDigit('1'))),
              _CalcBtn('2', height: buttonHeight, onTap: _btn(() => _inputDigit('2'))),
              _CalcBtn('3', height: buttonHeight, onTap: _btn(() => _inputDigit('3'))),
              _CalcBtn(
                '+',
                height: buttonHeight,
                onTap: _btn(() => _setOperation('+')),
                accent: true,
              ),
            ]),
            _buttonRow([
              _CalcBtn('±', height: buttonHeight, onTap: _btn(_toggleSign)),
              _CalcBtn('0', height: buttonHeight, onTap: _btn(() => _inputDigit('0'))),
              _CalcBtn(',', height: buttonHeight, onTap: _btn(_inputDecimal)),
              _CalcBtn(
                '=',
                height: buttonHeight,
                onTap: _btn(_equals),
                equals: true,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrapCreditCalcPage(
      secondary: true,
      pageTitle: 'Calcolatrice',
      current: CreditCalcNavItem.develop,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final buttonHeight = constraints.maxHeight < 640 ? 44.0 : 52.0;
          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _handleKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _calculatorCard(buttonHeight),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _memoryRow() {
    final enabled = _hasMemory;
    return Row(
      children: [
        _memoryBtn('MC', enabled ? _memoryClear : null),
        _memoryBtn('MR', enabled ? _memoryRecall : null),
        _memoryBtn('M+', _memoryAdd),
        _memoryBtn('M−', _memorySubtract),
        _memoryBtn('MS', _memoryStore),
        _memoryBtn('M˅', _showMemoryPanel, alwaysEnabled: true),
      ],
    );
  }

  Widget _memoryBtn(String label, VoidCallback? onTap, {bool alwaysEnabled = false}) {
    final active = alwaysEnabled || onTap != null;
    return Expanded(
      child: TextButton(
        onPressed: active ? onTap : null,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 6),
          foregroundColor: active ? Colors.black87 : Colors.black26,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buttonRow(List<Widget> buttons) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
  }
}

class _CalcBtn extends StatelessWidget {
  const _CalcBtn(
    this.label, {
    required this.onTap,
    this.height = 52,
    this.accent = false,
    this.equals = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final double height;
  final bool accent;
  final bool equals;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = equals
        ? const Color(0xFF6B5E2E)
        : accent
            ? const Color(0xFFF9F9F9)
            : Colors.white;
    final fg = equals ? Colors.white : Colors.black87;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: icon != null
              ? Icon(icon, size: 20, color: fg)
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: label.length > 2 ? 16 : 20,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
        ),
      ),
    );
  }
}
