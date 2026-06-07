import 'package:flutter/material.dart';

import '../../job/job_repository.dart';
import 'applications_page.dart';
import 'company_users_page.dart';
import 'gestione_lavori_page.dart';
import 'job_offers_page.dart';
import 'saved_page.dart';

enum PersonalJobMenuItem {
  jobOffers,
  savedJobs,
  myApplications,
  gestioneLavori,
  companyUsers,
}

final _jobRepo = JobRepository();
const _emptySaved = <String>{};
const _emptyApplied = <String>{};

extension PersonalJobMenuItemX on PersonalJobMenuItem {
  String get title => switch (this) {
        PersonalJobMenuItem.jobOffers => 'Offerte di lavoro',
        PersonalJobMenuItem.savedJobs => 'Salvati',
        PersonalJobMenuItem.myApplications => 'Le mie candidature',
        PersonalJobMenuItem.gestioneLavori => 'Gestione lavori',
        PersonalJobMenuItem.companyUsers => 'Utenti associati',
      };

  Widget page() => switch (this) {
        PersonalJobMenuItem.jobOffers => JobOffersPage(
            repo: _jobRepo,
            saved: _emptySaved,
            applied: _emptyApplied,
            onToggleSave: (_) {},
            onApply: (_) {},
          ),
        PersonalJobMenuItem.savedJobs => SavedPage(
            repo: _jobRepo,
            saved: _emptySaved,
            applied: _emptyApplied,
            onToggleSave: (_) {},
          ),
        PersonalJobMenuItem.myApplications => ApplicationsPage(
            repo: _jobRepo,
            applied: _emptyApplied,
            saved: _emptySaved,
            onWithdraw: (_) {},
          ),
        PersonalJobMenuItem.gestioneLavori => const GestioneLavoriPage(),
        PersonalJobMenuItem.companyUsers => const CompanyUsersPage(),
      };

  void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page()),
    );
  }
}
