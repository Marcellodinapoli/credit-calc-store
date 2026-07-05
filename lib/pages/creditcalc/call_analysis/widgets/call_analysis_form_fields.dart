import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/call_analysis/call_analysis_form_config.dart';

class CallAnalysisFormFields {
  static Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }

  static Widget textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboard = TextInputType.text,
    bool digitsOnly = false,
    int maxLines = 1,
    bool required = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        inputFormatters:
            digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
        ),
        validator: validator ??
            (required
                ? (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Campo obbligatorio';
                    }
                    return null;
                  }
                : null),
      ),
    );
  }

  static Widget dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(labelBuilder(e)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        validator: required
            ? (v) => v == null ? 'Seleziona un valore' : null
            : null,
      ),
    );
  }

  static Widget dateField({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    final display = value == null
        ? 'Tocca per scegliere'
        : '${value.day.toString().padLeft(2, '0')}/'
            '${value.month.toString().padLeft(2, '0')}/'
            '${value.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(now.year - 30),
            lastDate: now,
            helpText: label,
          );
          if (picked != null) onChanged(picked);
        },
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: value == null
                ? const Icon(Icons.calendar_today_outlined)
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => onChanged(null),
                  ),
          ),
          child: Text(
            display,
            style: TextStyle(
              color: value == null ? Colors.grey.shade600 : null,
            ),
          ),
        ),
      ),
    );
  }

  static Widget practiceStateDropdown({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final items = <String?>[null];
    items.addAll(
      CallAnalysisFormConfig.practiceStates.map((e) => e.key),
    );
    return dropdown<String?>(
      label: 'Stato della pratica',
      value: value,
      items: items,
      labelBuilder: (key) {
        if (key == null) return 'Seleziona…';
        return CallAnalysisFormConfig.labelForPracticeState(key) ?? key;
      },
      onChanged: onChanged,
    );
  }
}
