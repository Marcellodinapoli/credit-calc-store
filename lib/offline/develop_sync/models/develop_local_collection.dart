/// Collection dati Sviluppa sincronizzate tra dispositivi.
enum DevelopLocalCollection {
  creditors,
  calculations,
  fieldVisits,
  fieldActivities,
  fieldReminders,
  backofficePendingPlans,
  pdrSchedules,
  installmentMonitorConfigs,
}

extension DevelopLocalCollectionCodec on DevelopLocalCollection {
  String get storageKey => switch (this) {
        DevelopLocalCollection.creditors => 'creditors',
        DevelopLocalCollection.calculations => 'calculations',
        DevelopLocalCollection.fieldVisits => 'field_visits',
        DevelopLocalCollection.fieldActivities => 'field_activities',
        DevelopLocalCollection.fieldReminders => 'field_reminders',
        DevelopLocalCollection.backofficePendingPlans =>
          'backoffice_pending_plans',
        DevelopLocalCollection.pdrSchedules => 'pdr_schedules',
        DevelopLocalCollection.installmentMonitorConfigs =>
          'installment_monitor_configs',
      };

  static DevelopLocalCollection? fromStorageKey(String? raw) {
    return switch (raw) {
      'creditors' => DevelopLocalCollection.creditors,
      'calculations' => DevelopLocalCollection.calculations,
      'field_visits' => DevelopLocalCollection.fieldVisits,
      'field_activities' => DevelopLocalCollection.fieldActivities,
      'field_reminders' => DevelopLocalCollection.fieldReminders,
      'backoffice_pending_plans' =>
        DevelopLocalCollection.backofficePendingPlans,
      'pdr_schedules' => DevelopLocalCollection.pdrSchedules,
      'installment_monitor_configs' =>
        DevelopLocalCollection.installmentMonitorConfigs,
      _ => null,
    };
  }
}

const developLocalCollections = DevelopLocalCollection.values;

const storeDevelopSyncedCollections = {
  DevelopLocalCollection.creditors,
  DevelopLocalCollection.calculations,
  DevelopLocalCollection.fieldVisits,
  DevelopLocalCollection.fieldActivities,
  DevelopLocalCollection.fieldReminders,
  DevelopLocalCollection.backofficePendingPlans,
  DevelopLocalCollection.pdrSchedules,
  DevelopLocalCollection.installmentMonitorConfigs,
};
