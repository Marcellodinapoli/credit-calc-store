class DeviceTransferMeta {
  const DeviceTransferMeta({
    required this.status,
    required this.createdAtMs,
    required this.expiresAtMs,
    required this.senderDeviceId,
    required this.recordCount,
    required this.chunkCount,
    required this.totalBytes,
    required this.companyNames,
    this.releasedAtMs,
    this.transferMode = 'delta',
    this.syncBaselineMs,
    this.sinceMs,
  });

  final String status;
  final int createdAtMs;
  final int? releasedAtMs;
  final int expiresAtMs;
  final String senderDeviceId;
  final int recordCount;
  final int chunkCount;
  final int totalBytes;
  final Map<String, String> companyNames;
  final String transferMode;
  final int? syncBaselineMs;
  final int? sinceMs;

  bool get isFullTransfer => transferMode == 'full';
  bool get isDeltaTransfer => transferMode == 'delta';

  DateTime get sentAt => DateTime.fromMillisecondsSinceEpoch(
        (releasedAtMs != null && releasedAtMs! > 0)
            ? releasedAtMs!
            : createdAtMs,
      );

  bool get isPrepared => status == 'prepared';
  bool get isPending => status == 'pending';
  bool get isReceivable => isPending && !isExpired;
  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAtMs;

  factory DeviceTransferMeta.fromFirestore(Map<String, dynamic> data) {
    final namesRaw = data['companyNames'];
    final names = <String, String>{};
    if (namesRaw is Map) {
      for (final entry in namesRaw.entries) {
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) names[entry.key.toString()] = value;
      }
    }
    return DeviceTransferMeta(
      status: (data['status'] as String?) ?? '',
      createdAtMs: _readMs(data['createdAtMs']),
      releasedAtMs: _readOptionalMs(data['releasedAtMs']),
      expiresAtMs: _readMs(data['expiresAtMs']),
      senderDeviceId: (data['senderDeviceId'] as String?) ?? '',
      recordCount: (data['recordCount'] as num?)?.toInt() ?? 0,
      chunkCount: (data['chunkCount'] as num?)?.toInt() ?? 0,
      totalBytes: (data['totalBytes'] as num?)?.toInt() ?? 0,
      companyNames: names,
      transferMode: (data['transferMode'] as String?) ?? 'full',
      syncBaselineMs: _readOptionalMs(data['syncBaselineMs']),
      sinceMs: _readOptionalMs(data['sinceMs']),
    );
  }

  static int _readMs(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  static int? _readOptionalMs(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }
}

class DeviceTransferPrepareResult {
  const DeviceTransferPrepareResult({
    required this.recordCount,
    required this.totalBytes,
    required this.companyNames,
    required this.preparedAt,
    required this.isDelta,
    required this.pendingChanges,
  });

  final int recordCount;
  final int totalBytes;
  final List<String> companyNames;
  final DateTime preparedAt;
  final bool isDelta;
  final int pendingChanges;
}

/// Stato locale usato per decidere invio incrementale e confronto tra dispositivi.
class DeviceTransferLocalState {
  const DeviceTransferLocalState({
    required this.lastSyncAtMs,
    required this.maxUpdatedAtMs,
    required this.pendingChangeCount,
    required this.localRecordCount,
  });

  final int lastSyncAtMs;
  final int maxUpdatedAtMs;
  final int pendingChangeCount;
  final int localRecordCount;

  bool get hasPendingChanges => pendingChangeCount > 0;
  bool get neverSynced => lastSyncAtMs <= 0;
}

/// Stato pubblicato dall'altro dispositivo sulla pagina Sincronizza.
class DeviceTransferPeerState {
  const DeviceTransferPeerState({
    required this.deviceId,
    required this.lastSeenAtMs,
    required this.lastSyncAtMs,
    required this.maxUpdatedAtMs,
    required this.pendingChangeCount,
    required this.localRecordCount,
  });

  final String deviceId;
  final int lastSeenAtMs;
  final int lastSyncAtMs;
  final int maxUpdatedAtMs;
  final int pendingChangeCount;
  final int localRecordCount;

  bool get hasPendingChanges => pendingChangeCount > 0;

  factory DeviceTransferPeerState.fromFirestore(
    String deviceId,
    Map<String, dynamic> data,
  ) {
    return DeviceTransferPeerState(
      deviceId: deviceId,
      lastSeenAtMs: _readMs(data['lastSeenAtMs']),
      lastSyncAtMs: _readMs(data['lastSyncAtMs']),
      maxUpdatedAtMs: _readMs(data['maxUpdatedAtMs']),
      pendingChangeCount: (data['pendingChangeCount'] as num?)?.toInt() ?? 0,
      localRecordCount: (data['localRecordCount'] as num?)?.toInt() ?? 0,
    );
  }

  static int _readMs(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }
}

enum DeviceTransferSyncHint {
  aligned,
  youShouldSend,
  peerShouldSend,
  bothHaveChanges,
  peerEmptyNeedsFull,
  waitingForPeer,
}

abstract final class DeviceTransferSyncAdvisor {
  static DeviceTransferSyncHint advise({
    required DeviceTransferLocalState local,
    DeviceTransferPeerState? peer,
  }) {
    if (peer == null) {
      if (local.hasPendingChanges) {
        return DeviceTransferSyncHint.youShouldSend;
      }
      return DeviceTransferSyncHint.waitingForPeer;
    }

    if (peer.localRecordCount == 0 && local.localRecordCount > 0) {
      return DeviceTransferSyncHint.peerEmptyNeedsFull;
    }

    final baselinesMatch =
        local.lastSyncAtMs > 0 && peer.lastSyncAtMs == local.lastSyncAtMs;

    if (baselinesMatch &&
        !local.hasPendingChanges &&
        !peer.hasPendingChanges) {
      return DeviceTransferSyncHint.aligned;
    }

    if (local.hasPendingChanges && !peer.hasPendingChanges) {
      return DeviceTransferSyncHint.youShouldSend;
    }
    if (peer.hasPendingChanges && !local.hasPendingChanges) {
      return DeviceTransferSyncHint.peerShouldSend;
    }
    if (local.hasPendingChanges && peer.hasPendingChanges) {
      if (local.maxUpdatedAtMs > peer.maxUpdatedAtMs) {
        return DeviceTransferSyncHint.youShouldSend;
      }
      if (peer.maxUpdatedAtMs > local.maxUpdatedAtMs) {
        return DeviceTransferSyncHint.peerShouldSend;
      }
      return DeviceTransferSyncHint.bothHaveChanges;
    }

    if (!baselinesMatch) {
      if (local.localRecordCount == 0 && peer.localRecordCount > 0) {
        return DeviceTransferSyncHint.peerShouldSend;
      }
      if (local.localRecordCount > 0 && peer.localRecordCount == 0) {
        return DeviceTransferSyncHint.peerEmptyNeedsFull;
      }
    }

    return DeviceTransferSyncHint.waitingForPeer;
  }

  static String hintMessage(DeviceTransferSyncHint hint) {
    return switch (hint) {
      DeviceTransferSyncHint.aligned =>
        'I dispositivi risultano allineati: nessun aggiornamento da trasferire.',
      DeviceTransferSyncHint.youShouldSend =>
        'Questo dispositivo ha modifiche da inviare. Prepara il pacchetto.',
      DeviceTransferSyncHint.peerShouldSend =>
        'L\'altro dispositivo ha modifiche più recenti. Attendi l\'invio da lì.',
      DeviceTransferSyncHint.bothHaveChanges =>
        'Entrambi i dispositivi hanno modifiche. Invia prima da quello con '
            'più aggiornamenti; dopo la ricezione potrai inviare le restanti.',
      DeviceTransferSyncHint.peerEmptyNeedsFull =>
        'L\'altro dispositivo è vuoto: verrà inviato l\'intero archivio.',
      DeviceTransferSyncHint.waitingForPeer =>
        'Apri Sincronizza sull\'altro dispositivo con lo stesso account.',
    };
  }
}

class DeviceTransferSendResult {
  const DeviceTransferSendResult({
    required this.recordCount,
    required this.chunkCount,
    required this.sentAt,
    required this.expiresAt,
    required this.totalBytes,
    required this.companyNames,
  });

  final int recordCount;
  final int chunkCount;
  final DateTime sentAt;
  final DateTime expiresAt;
  final int totalBytes;
  final List<String> companyNames;
}

class DeviceTransferReceiveResult {
  const DeviceTransferReceiveResult({
    required this.importedRecords,
    required this.sentAt,
    required this.receivedAt,
    required this.totalBytes,
  });

  final int importedRecords;
  final DateTime sentAt;
  final DateTime receivedAt;
  final int totalBytes;
}

class DeviceTransferLocalHistory {
  const DeviceTransferLocalHistory({
    this.lastSendAt,
    this.lastSendBytes,
    this.lastReceiveAt,
    this.lastReceiveSentAt,
    this.lastReceiveBytes,
  });

  final DateTime? lastSendAt;
  final int? lastSendBytes;
  final DateTime? lastReceiveAt;
  final DateTime? lastReceiveSentAt;
  final int? lastReceiveBytes;
}

abstract final class DeviceTransferFormat {
  static String bytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '${(value / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static String dateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year;
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }
}
