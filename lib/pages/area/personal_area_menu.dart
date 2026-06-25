import 'package:credit_calc_core/credit_calc_core.dart';
import 'package:flutter/material.dart';

import 'consents_page.dart';
import 'direct_support_page.dart';
import 'community_list_page.dart';
import 'guide_page.dart';
import 'my_data_page.dart';
import 'notification_preferences_page.dart';
import 'visit_itinerary_page.dart';

/// Voci Area personale nel menù panino.
enum PersonalAreaMenuItem {
  visitItinerary,
  myData,
  subscription,
  directSupport,
  community,
  guide,
  notificationPreferences,
  privacyConsents,
}

extension PersonalAreaMenuItemX on PersonalAreaMenuItem {
  String get title => switch (this) {
        PersonalAreaMenuItem.visitItinerary => 'Itinerario',
        PersonalAreaMenuItem.myData => 'I miei dati',
        PersonalAreaMenuItem.subscription => 'Il mio piano',
        PersonalAreaMenuItem.directSupport => 'Assistenza diretta',
        PersonalAreaMenuItem.community => 'Community',
        PersonalAreaMenuItem.guide => 'Guida all\'utilizzo',
        PersonalAreaMenuItem.notificationPreferences => 'Notifiche',
        PersonalAreaMenuItem.privacyConsents => 'Privacy e consensi',
      };

  Widget page() => switch (this) {
        PersonalAreaMenuItem.visitItinerary => const VisitItineraryPage(),
        PersonalAreaMenuItem.myData => const MyDataPage(),
        PersonalAreaMenuItem.subscription => const SubscriptionAccountPage(),
        PersonalAreaMenuItem.directSupport => const DirectSupportPage(),
        PersonalAreaMenuItem.community => const CommunityListPage(),
        PersonalAreaMenuItem.guide => const GuidePage(),
        PersonalAreaMenuItem.notificationPreferences =>
          const NotificationPreferencesPage(),
        PersonalAreaMenuItem.privacyConsents => const ConsentsPage(),
      };

  void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page()),
    );
  }
}
