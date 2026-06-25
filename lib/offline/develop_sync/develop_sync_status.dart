enum DevelopSyncState { idle, syncing, error }

class DevelopSyncStatus {
  const DevelopSyncStatus({
    required this.state,
    this.lastSuccessAt,
    this.errorMessage,
  });

  static const idle = DevelopSyncStatus(state: DevelopSyncState.idle);

  final DevelopSyncState state;
  final DateTime? lastSuccessAt;
  final String? errorMessage;

  bool get isSyncing => state == DevelopSyncState.syncing;
  bool get hasError => state == DevelopSyncState.error;
}
