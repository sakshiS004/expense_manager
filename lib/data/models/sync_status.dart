enum SyncStatus { synced, pendingCreate, pendingUpdate, pendingDelete, failed }

extension SyncStatusX on SyncStatus {
  String get value => name;

  static SyncStatus fromValue(String? value) {
    return SyncStatus.values.firstWhere(
          (e) => e.name == value,
      orElse: () => SyncStatus.synced,
    );
  }
}