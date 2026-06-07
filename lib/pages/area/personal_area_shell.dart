import 'package:flutter/material.dart';

import '../../ui/layout/page_shell.dart';

/// Layout secondario per pagine Area personale (titolo + indietro).
class PersonalAreaShell extends StatelessWidget {
  final String pageTitle;
  final Widget body;
  final Widget? bottomBar;

  const PersonalAreaShell({
    super.key,
    required this.pageTitle,
    required this.body,
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      pageTitle: pageTitle,
      bottomBar: bottomBar,
      body: body,
    );
  }
}
