import 'package:flutter/material.dart';

import '../services/account_menu_badge_notifier.dart';

/// Icona menù tre puntini con badge se ci sono novità nel menù account.
class AccountMenuBadgeIconButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AccountMenuBadgeIconButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AccountMenuBadges>(
      valueListenable: AccountMenuBadgeNotifier.instance.badges,
      builder: (context, badges, _) {
        return Badge(
          isLabelVisible: badges.hasAny,
          child: IconButton(
            tooltip: 'Menu',
            onPressed: onPressed,
            icon: const Icon(Icons.more_vert),
          ),
        );
      },
    );
  }
}

Widget accountMenuBadgeDot({required bool visible}) {
  if (!visible) return const SizedBox.shrink();
  return Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: Colors.red,
      shape: BoxShape.circle,
    ),
  );
}
