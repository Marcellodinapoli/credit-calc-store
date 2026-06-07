import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dimensions.dart';

/// SnackBar con testo centrato e margine sopra il banner cookie (tutto il sito).
class AppSnackBar {
  AppSnackBar._();

  static SnackBar normalize(SnackBar original, BuildContext context) {
    final theme = Theme.of(context).snackBarTheme;
    final message = _extractMessage(original.content);
    final bottom = Dimensions.overlayBottomInset(context) + 12;

    EdgeInsets margin = EdgeInsets.fromLTRB(16, 0, 16, bottom);
    if (original.margin != null) {
      final m = original.margin!.resolve(Directionality.of(context));
      margin = EdgeInsets.fromLTRB(
        m.left > 0 ? m.left : 16,
        m.top,
        m.right > 0 ? m.right : 16,
        math.max(m.bottom, bottom),
      );
    }

    TextStyle? textStyle;
    if (original.content is Text) {
      textStyle = (original.content as Text).style;
    }
    textStyle ??= theme.contentTextStyle;

    return SnackBar(
      content: Center(
        child: Text(
          message.isEmpty ? ' ' : message,
          textAlign: TextAlign.center,
          style: textStyle,
        ),
      ),
      action: original.action,
      duration: original.duration,
      backgroundColor: original.backgroundColor ?? theme.backgroundColor,
      behavior: SnackBarBehavior.floating,
      margin: margin,
      shape: original.shape ?? theme.shape,
      elevation: original.elevation ?? theme.elevation,
      width: original.width ?? theme.width,
      showCloseIcon: original.showCloseIcon,
      closeIconColor: original.closeIconColor,
      dismissDirection: original.dismissDirection,
    );
  }

  static String _extractMessage(Widget? content) {
    if (content == null) return '';

    if (content is Text) {
      if (content.data != null && content.data!.isNotEmpty) {
        return content.data!;
      }
      return content.textSpan?.toPlainText() ?? '';
    }

    if (content is RichText) {
      return content.text.toPlainText();
    }

    if (content is Center) {
      return _extractMessage(content.child);
    }

    if (content is Padding) {
      return _extractMessage(content.child);
    }

    if (content is Align) {
      return _extractMessage(content.child);
    }

    if (content is Row) {
      for (final child in content.children) {
        final text = _extractMessage(child);
        if (text.isNotEmpty) return text;
      }
    }

    if (content is Column) {
      for (final child in content.children) {
        final text = _extractMessage(child);
        if (text.isNotEmpty) return text;
      }
    }

    return '';
  }
}

/// Intercetta tutti gli [SnackBar] e applica testo centrato + posizione leggibile.
class CenteredScaffoldMessenger extends ScaffoldMessenger {
  const CenteredScaffoldMessenger({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => _CenteredScaffoldMessengerState();
}

class _CenteredScaffoldMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    return super.showSnackBar(
      AppSnackBar.normalize(snackBar, context),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }
}
