import 'package:flutter/material.dart';

import 'itinerary_day_summary_card.dart';

class ManagementSectionIntro extends StatelessWidget {
  const ManagementSectionIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ItineraryDaySummaryCard(),
      ],
    );
  }
}
