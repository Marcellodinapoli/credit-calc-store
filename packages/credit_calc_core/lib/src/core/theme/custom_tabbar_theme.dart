import 'package:flutter/material.dart';
import 'dimensions.dart';

/// 🔹 Tema centralizzato per TabBar
class CustomTabBarTheme {
  static Widget build({
    required BuildContext context,
    required TabController controller,
    required List<Widget> tabs,
    bool? isScrollable,
  }) {
    return TabBar(
      controller: controller,
      tabs: tabs,
      isScrollable:
          isScrollable ?? tabs.length > 2 || Dimensions.isTablet(context),
      tabAlignment: TabAlignment.start,
      labelColor: Colors.black, // testo selezionato
      unselectedLabelColor: Colors.black54, // testo non selezionato
      indicatorColor: const Color(0xFFFFA726), // colore linea sotto tab
      indicatorWeight: 3,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
