import 'package:flutter/material.dart';

/// Formattazione importi in stile italiano (es. 1.500,00 €).
abstract final class EuroFormat {
  static const euroSuffix = ' €';

  static String format(double value, {int decimalDigits = 2}) {
    final negative = value < 0;
    final absValue = value.abs();
    final fixed = absValue.toStringAsFixed(decimalDigits);
    final parts = fixed.split('.');
    final intPart = parts.first;
    final decPart =
        decimalDigits > 0 && parts.length > 1 ? parts[1] : '';

    final grouped = _groupIntPart(intPart);
    final body = decimalDigits > 0 && decPart.isNotEmpty
        ? '$grouped,$decPart'
        : grouped;
    return '${negative ? '-' : ''}$body$euroSuffix';
  }

  static String? formatNullable(double? value, {int decimalDigits = 2}) {
    if (value == null) return null;
    return format(value, decimalDigits: decimalDigits);
  }

  static String formatNum(num? value, {int decimalDigits = 2}) {
    if (value == null) return '';
    return format(value.toDouble(), decimalDigits: decimalDigits);
  }

  /// Importo in euro interi con ,00 (es. 91,00 €).
  static String formatWholeEuro(double value) {
    return format(value.roundToDouble(), decimalDigits: 2);
  }

  /// Parsing da testo campo (es. 1.500,00 €, 1500, 1500,00).
  static double? parse(String? text) {
    if (text == null) return null;
    var s = text.trim();
    if (s.isEmpty) return null;

    s = s.replaceAll('€', '').trim();
    if (s.isEmpty) return null;

    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      final dotCount = '.'.allMatches(s).length;
      if (dotCount > 1) {
        s = s.replaceAll('.', '');
      } else if (dotCount == 1) {
        final fraction = s.split('.').last;
        if (fraction.length == 3) {
          s = s.replaceAll('.', '');
        }
      }
    }

    return double.tryParse(s);
  }

  static int? parseInt(String? text) {
    final value = parse(text);
    if (value == null) return null;
    return value.round();
  }

  /// Cifre intere per salvataggio (fasce PDR, importi senza decimali).
  static String storageDigits(String? text) {
    final value = parseInt(text);
    if (value == null) return '';
    return value.toString();
  }

  static void applyToController(
    TextEditingController controller, {
    int decimalDigits = 2,
  }) {
    final value = parse(controller.text);
    if (value == null) {
      if (controller.text.trim().isEmpty) controller.text = '';
      return;
    }
    controller.text = format(value, decimalDigits: decimalDigits);
  }
}

String _groupIntPart(String intPart) {
  if (intPart.isEmpty) return '0';
  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final fromEnd = intPart.length - i;
    if (i > 0 && fromEnd % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(intPart[i]);
  }
  return buffer.toString();
}
