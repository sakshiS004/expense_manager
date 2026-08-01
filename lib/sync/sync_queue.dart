import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/local/db_helper.dart';

enum SyncQueueStatus { synced, syncing, offline, error }

class SyncQueue {
  SyncQueue({
    DBHelper? dbHelper,
    Connectivity? connectivity,
    Future<void> Function()? onSync,
  })  : _dbHelper = dbHelper ?? DBHelper.instance,
        _connectivity = connectivity ?? Connectivity(),
        _onSync = onSync {
    _initialized = _init();
  }

  static const _syncTimeout = Duration(seconds: 20);

  final DBHelper _dbHelper;
  final Connectivity _connectivity;
  final Future<void> Function()? _onSync;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  late final Future<void> _initialized;
  bool _disposed = false;

  final ValueNotifier<bool> isOnline = ValueNotifier(true);
  final ValueNotifier<SyncQueueStatus> syncStatus = ValueNotifier(SyncQueueStatus.synced);
  final ValueNotifier<int> pendingChangeCount = ValueNotifier(0);

  /// Human-readable reason for the last sync failure. Shown in Settings so
  /// "Sync error" isn't a dead end — check this after a failed sync.
  String? lastError;

  Future<void> get ready => _initialized;

  Future<void> _init() async {
    final initial = await _connectivity.checkConnectivity();
    if (_disposed) return;
    _handleConnectivityChange(initial, triggerSyncOnReconnect: false);
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
    await refreshPendingCount();

    // Push anything left pending from a previous offline session as soon as
    // we start up online, instead of waiting for a live offline->online
    // transition or a manual "Sync Now" tap.
    if (!_disposed && isOnline.value && pendingChangeCount.value > 0) {
      unawaited(triggerSync());
    }
  }

  void _handleConnectivityChange(
      List<ConnectivityResult> results, {
        bool triggerSyncOnReconnect = true,
      }) {
    if (_disposed) return;

    final wasOnline = isOnline.value;
    final nowOnline = results.any((r) => r != ConnectivityResult.none);
    isOnline.value = nowOnline;

    if (!nowOnline) {
      syncStatus.value = SyncQueueStatus.offline;
      return;
    }

    if (!wasOnline && triggerSyncOnReconnect) {
      triggerSync();
    } else if (syncStatus.value == SyncQueueStatus.offline) {
      syncStatus.value = SyncQueueStatus.synced;
    }
  }

  Future<void> triggerSync() async {
    if (_disposed) return;
    if (!isOnline.value || syncStatus.value == SyncQueueStatus.syncing) return;

    syncStatus.value = SyncQueueStatus.syncing;
    lastError = null;
    try {
      await _onSync?.call().timeout(
        _syncTimeout,
        onTimeout: () => throw TimeoutException(
          'Sync timed out after ${_syncTimeout.inSeconds}s — check your '
              'connection or Firestore rules/indexes.',
        ),
      );
      if (_disposed) return;
      syncStatus.value = SyncQueueStatus.synced;
    } catch (e) {
      if (_disposed) return;
      lastError = e.toString();
      debugPrint('SyncQueue: sync failed — $e');
      syncStatus.value = SyncQueueStatus.error;
    } finally {
      await refreshPendingCount();
    }
  }

  Future<void> refreshPendingCount() async {
    final count = await _dbHelper.countPendingChanges();
    if (_disposed) return;
    pendingChangeCount.value = count;
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    isOnline.dispose();
    syncStatus.dispose();
    pendingChangeCount.dispose();
  }
}
