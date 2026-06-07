import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import 'job_theme.dart' show kJobBrand, kJobTextOnBrand;

/// Stili pulsante espliciti (sempre leggibili su sfondo chiaro).
abstract final class AdaptiveButtonStyles {
  static ButtonStyle calcFilled({bool enabled = true}) {
    return FilledButton.styleFrom(
      backgroundColor: ProjectColors.calc,
      foregroundColor: Colors.white,
      disabledBackgroundColor: ProjectColors.calc,
      disabledForegroundColor: Colors.white,
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      elevation: 2,
      shadowColor: ProjectColors.calc.withValues(alpha: 0.4),
    );
  }

  static ButtonStyle calcOutlinedDanger() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.red.shade800,
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.red.shade400, width: 1.5),
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    );
  }

  static ButtonStyle formElevated() {
    return ElevatedButton.styleFrom(
      backgroundColor: ProjectColors.form,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.grey.shade300,
      disabledForegroundColor: Colors.grey.shade600,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle formElevatedMuted() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.grey.shade300,
      foregroundColor: Colors.black87,
      disabledBackgroundColor: Colors.grey.shade200,
      disabledForegroundColor: Colors.grey.shade500,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static ButtonStyle jobFilled({bool enabled = true}) {
    return FilledButton.styleFrom(
      backgroundColor: kJobBrand,
      foregroundColor: kJobTextOnBrand,
      disabledBackgroundColor: Colors.grey.shade300,
      disabledForegroundColor: Colors.grey.shade600,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle jobElevated() {
    return ElevatedButton.styleFrom(
      backgroundColor: kJobBrand,
      foregroundColor: kJobTextOnBrand,
      disabledBackgroundColor: Colors.grey.shade300,
      disabledForegroundColor: Colors.grey.shade600,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle areaElevated() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1565C0),
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      elevation: 2,
    );
  }

  static ButtonStyle dangerElevated() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.red.shade700,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 48),
    );
  }
}
