import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Segnaposto per bordo rosso senza testo errore visibile sotto il campo.
const String requiredFieldBorderOnly = ' ';

const TextStyle _hiddenErrorTextStyle = TextStyle(
  fontSize: 0,
  height: 0,
  color: Colors.transparent,
);

/// Restituisce testo errore (o solo bordo) per evidenziare un campo obbligatorio vuoto.
String? requiredFieldError(bool invalid, {String? message}) {
  if (!invalid) return null;
  return message ?? requiredFieldBorderOnly;
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderSide: BorderSide(color: color, width: width),
  );
}

/// Decorazione standard per campi compilabili (come Sviluppo piano di rientro).
InputDecoration appFormFieldDecoration(
  String label, {
  String? errorText,
}) {
  final hasError = errorText != null && errorText.isNotEmpty;
  final borderOnly = errorText == requiredFieldBorderOnly;
  final errorBorder = _fieldBorder(const Color(0xFFC62828), width: 1.5);
  final normalBorder = _fieldBorder(Colors.grey.shade400);

  return InputDecoration(
    labelText: label,
    errorText: hasError ? errorText : null,
    errorStyle: borderOnly ? _hiddenErrorTextStyle : null,
    errorMaxLines: borderOnly ? 1 : null,
    border: hasError ? errorBorder : normalBorder,
    enabledBorder: hasError ? errorBorder : normalBorder,
    focusedBorder: hasError
        ? errorBorder
        : _fieldBorder(const Color(0xFF0A66C2), width: 2),
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder,
  );
}

/// Gestisce Tab / Shift+Tab: focus sul campo successivo o precedente.
KeyEventResult appHandleTabKey(
  FocusNode node,
  KeyEvent event,
  BuildContext context, {
  VoidCallback? onCommit,
}) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  if (event.logicalKey != LogicalKeyboardKey.tab) {
    return KeyEventResult.ignored;
  }
  onCommit?.call();
  if (HardwareKeyboard.instance.isShiftPressed) {
    FocusScope.of(context).previousFocus();
  } else {
    FocusScope.of(context).nextFocus();
  }
  return KeyEventResult.handled;
}

/// Wrapper per intercettare Tab e avanzare il focus (anche su dropdown / date).
Widget appTabFocusShell(
  BuildContext context, {
  required Widget child,
  VoidCallback? onCommit,
  FocusNode? focusNode,
  ValueChanged<bool>? onFocusChange,
}) {
  return Focus(
    focusNode: focusNode,
    onFocusChange: onFocusChange,
    onKeyEvent: (node, event) =>
        appHandleTabKey(node, event, context, onCommit: onCommit),
    child: child,
  );
}

/// Ordine di tabulazione esplicito dentro un [FocusTraversalGroup].
Widget appTabOrder(num order, Widget child) {
  return FocusTraversalOrder(
    order: NumericFocusOrder(order.toDouble()),
    child: child,
  );
}

/// Campo importo in euro con tastiera numerica adattata al dispositivo.
Widget appAdaptiveEuroTextField({
  required TextEditingController controller,
  required InputDecoration decoration,
  Key? fieldKey,
  FocusNode? focusNode,
  TextInputAction? textInputAction,
  ValueChanged<String>? onChanged,
  VoidCallback? onEditingComplete,
}) {
  return TextField(
    key: fieldKey,
    controller: controller,
    focusNode: focusNode,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: textInputAction,
    onChanged: onChanged,
    onEditingComplete: onEditingComplete,
    decoration: decoration,
  );
}

/// Campo testo con padding e stile condiviso.
Widget appFormTextField({
  required String label,
  required TextEditingController controller,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  bool readOnly = false,
  ValueChanged<String>? onChanged,
  VoidCallback? onEditingComplete,
  int maxLines = 1,
  String? errorText,
  EdgeInsetsGeometry padding = const EdgeInsets.only(bottom: 12),
}) {
  return Padding(
    padding: padding,
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      maxLines: maxLines,
      decoration: appFormFieldDecoration(label, errorText: errorText),
    ),
  );
}
