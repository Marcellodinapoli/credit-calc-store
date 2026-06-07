import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

InputDecoration appFormFieldDecoration(
  String label, {
  String? errorText,
}) {
  return InputDecoration(
    labelText: label,
    errorText: errorText,
    border: const OutlineInputBorder(),
  );
}

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
