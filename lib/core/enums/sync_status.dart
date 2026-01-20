enum SyncStatus {
  synced,
  pending,
  failed,
}

extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.pending:
        return 'Pending';
      case SyncStatus.failed:
        return 'Failed';
    }
  }

  String get code {
    switch (this) {
      case SyncStatus.synced:
        return 'SYNCED';
      case SyncStatus.pending:
        return 'PENDING';
      case SyncStatus.failed:
        return 'FAILED';
    }
  }

  static SyncStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SYNCED':
        return SyncStatus.synced;
      case 'PENDING':
        return SyncStatus.pending;
      case 'FAILED':
        return SyncStatus.failed;
      default:
        return SyncStatus.pending;
    }
  }
}
