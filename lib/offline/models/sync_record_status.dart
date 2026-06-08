enum SyncRecordStatus {
  synced,
  pending,
  conflict,
}

extension SyncRecordStatusCodec on SyncRecordStatus {
  String get storageValue => name;

  static SyncRecordStatus fromStorage(String? raw) {
    return SyncRecordStatus.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => SyncRecordStatus.synced,
    );
  }
}
