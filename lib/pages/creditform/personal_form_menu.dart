import 'package:flutter/material.dart';

import 'company_collaborators_page.dart';
import 'courses_page.dart';
import 'listening_page.dart';
import 'progress_page.dart';
import 'review_page.dart';
import 'roleplay_page.dart';

enum PersonalFormMenuItem {
  courses,
  listening,
  roleplay,
  progress,
  review,
  companyCollaborators,
}

extension PersonalFormMenuItemX on PersonalFormMenuItem {
  String get title => switch (this) {
        PersonalFormMenuItem.courses => 'Corsi',
        PersonalFormMenuItem.listening => 'Warm-up',
        PersonalFormMenuItem.roleplay => 'Role Play',
        PersonalFormMenuItem.progress => 'I miei progressi',
        PersonalFormMenuItem.review => 'Recensione',
        PersonalFormMenuItem.companyCollaborators => 'Collaboratori',
      };

  Widget page() => switch (this) {
        PersonalFormMenuItem.courses => const CoursesPage(),
        PersonalFormMenuItem.listening => const ListeningPage(),
        PersonalFormMenuItem.roleplay => const RoleplayPage(),
        PersonalFormMenuItem.progress => const CrediFormProgressPage(),
        PersonalFormMenuItem.review => const ReviewPage(),
        PersonalFormMenuItem.companyCollaborators =>
          const CompanyCollaboratorsPage(),
      };

  void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page()),
    );
  }
}
