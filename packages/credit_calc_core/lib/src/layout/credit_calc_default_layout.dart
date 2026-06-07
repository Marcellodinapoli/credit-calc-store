import 'package:flutter/material.dart';

import '../core/theme/project_colors.dart';
import '../nav/credit_calc_nav.dart';

/// Layout predefinito quando l'host (Planet / desktop) non registra un wrapper.
class CreditCalcDefaultLayout extends StatelessWidget {
  final String pageTitle;
  final Widget body;
  final CreditCalcNavItem? current;
  final bool showBack;

  const CreditCalcDefaultLayout({
    super.key,
    required this.pageTitle,
    required this.body,
    this.current,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFECEFF1),
        elevation: 1,
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
        title: Row(
          children: [
            const Text(
              'Credit',
              style: TextStyle(
                color: ProjectColors.calc,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Calc',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (pageTitle.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                '· $pageTitle',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: body,
        ),
      ),
    );
  }
}
