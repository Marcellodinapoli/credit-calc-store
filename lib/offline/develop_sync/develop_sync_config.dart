/// Versione schema payload sync multi-dispositivo Sviluppa.
abstract final class DevelopSyncConfig {
  static const schemaVersion = 1;
  static const pushDebounceMs = 2500;
  static const metaLastPulledMs = 'sync_last_pulled_ms';
  static const metaLastPushedMs = 'sync_last_pushed_ms';
}
