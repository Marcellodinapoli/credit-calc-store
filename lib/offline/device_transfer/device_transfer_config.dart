/// Configurazione trasferimento una tantum tra dispositivi.
abstract final class DeviceTransferConfig {
  static const schemaVersion = 2;
  static const transferDocId = 'current';
  static const ttlMinutes = 30;
  static const recordsPerChunk = 40;
  static const cipherMetaPrefix = 'local_cipher_key';
  static const prefsLastSyncAt = 'device_transfer_last_sync_at_ms';
  static const prefsLastSendAt = 'device_transfer_last_send_at_ms';
  static const prefsLastSendBytes = 'device_transfer_last_send_bytes';
  static const prefsLastReceiveAt = 'device_transfer_last_receive_at_ms';
  static const prefsLastReceiveSentAt = 'device_transfer_last_receive_sent_at_ms';
  static const prefsLastReceiveBytes = 'device_transfer_last_receive_bytes';
  static const presenceMaxAgeSeconds = 45;
  static const presenceHeartbeatSeconds = 8;
  /// Indice record pubblicato in presenza (collection::id → updatedAtMs).
  static const maxPresenceRecordVersions = 2000;
}
