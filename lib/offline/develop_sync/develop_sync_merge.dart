import 'models/develop_local_record.dart';
import 'develop_sync_wire_record.dart';

/// Risoluzione conflitti last-write-wins per record Sviluppa.
abstract final class DevelopSyncMerge {
  static bool remoteWins({
    required DevelopLocalRecord? local,
    required DevelopSyncWireRecord remote,
  }) {
    if (local == null) return true;
    final localMs = local.updatedAt.millisecondsSinceEpoch;
    if (remote.updatedAtMs > localMs) return true;
    if (remote.updatedAtMs < localMs) return false;
    return true;
  }
}
