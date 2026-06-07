import 'package:flutter/material.dart';

import '../dimensions.dart';

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
      labelColor: Colors.black,
      unselectedLabelColor: Colors.black54,
      indicatorColor: const Color(0xFFFFA726),
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
