import 'package:flutter/material.dart';

import 'consents_page.dart';
import 'direct_support_page.dart';
import 'community_list_page.dart';
import 'guide_page.dart';
import 'my_data_page.dart';
import 'notification_preferences_page.dart';

/// Voci Area personale nel menù panino.
enum PersonalAreaMenuItem {
  myData,
  directSupport,
  community,
  guide,
  notificationPreferences,
  privacyConsents,
}

extension PersonalAreaMenuItemX on PersonalAreaMenuItem {
  String get title => switch (this) {
        PersonalAreaMenuItem.myData => 'I miei dati',
        PersonalAreaMenuItem.directSupport => 'Assistenza diretta',
        PersonalAreaMenuItem.community => 'Community',
        PersonalAreaMenuItem.guide => 'Guida all\'utilizzo',
        PersonalAreaMenuItem.notificationPreferences => 'Aggiornamenti',
        PersonalAreaMenuItem.privacyConsents => 'Privacy e consensi',
      };

  Widget page() => switch (this) {
        PersonalAreaMenuItem.myData => const MyDataPage(),
        PersonalAreaMenuItem.directSupport => const DirectSupportPage(),
        PersonalAreaMenuItem.community => const CommunityListPage(),
        PersonalAreaMenuItem.guide => const GuidePage(),
        PersonalAreaMenuItem.notificationPreferences =>
          const NotificationPreferencesPage(),
        PersonalAreaMenuItem.privacyConsents => const PrivacyConsentsPage(),
      };

  void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page()),
    );
  }
}
