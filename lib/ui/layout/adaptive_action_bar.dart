import 'package:flutter/material.dart';

import '../../core/dimensions.dart';

class AdaptiveActionBarAction {
  final Widget child;
  final int flex;

  const AdaptiveActionBarAction({
    required this.child,
    this.flex = 1,
  });
}

/// Barra azioni in fondo: affiancata con 2 pulsanti, impilata se ce ne sono di più.
class AdaptiveActionBar extends StatelessWidget {
  final List<AdaptiveActionBarAction> actions;
  final double spacing;

  const AdaptiveActionBar({
    super.key,
    required this.actions,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final useRow = actions.length <= 2 || !Dimensions.isPhone(context);

    final bar = useRow
        ? Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(flex: actions[i].flex, child: actions[i].child),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                SizedBox(width: double.infinity, child: actions[i].child),
              ],
            ],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border(
          top: BorderSide(color: Colors.grey.shade400),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, spacing, 8, 8),
        child: bar,
      ),
    );
  }
}
