import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/db_helper.dart';
import '../data/models/sync_status.dart';
import '../data/remote/firestore_service.dart';
import '../providers/transaction_provider.dart';
import 'conflict_resolver.dart';

class SyncService {
  SyncService({
    required String userId,
    required TransactionProvider transactionProvider,
    DBHelper? dbHelper,
    FirestoreService? firestoreService,
    ConflictResolver? conflictResolver,
  })  : _userId = userId,
        _transactionProvider = transactionProvider,
        _dbHelper = dbHelper ?? DBHelper.instance,
        _firestore = firestoreService ?? FirestoreService(),
        _resolver = conflictResolver ?? const ConflictResolver();

  final String _userId;
  final TransactionProvider _transactionProvider;
  final DBHelper _dbHelper;
  final FirestoreService _firestore;
  final ConflictResolver _resolver;

  String get _userLastSyncKey => 'lastSyncAt_$_userId';

  /// Primary sync execution wrapper.
  Future<void> sync() => runSync();

  Future<void> runSync() async {
    // 1. Guard against offline mode without marking records as failed
    final isOnline = await _hasInternetConnection();
    if (!isOnline) {
      debugPrint("Sync skipped: Device is offline.");
      return;
    }

    try {
      final lastSyncAt = await _getLastSyncAt();
      final syncStartedAt = DateTime.now();

      // 2. Push local pending edits to Firestore
      await _pushLocalChanges();

      // 3. Pull cloud updates since last sync
      await _pullCloudChanges(lastSyncAt);

      // 4. Save timestamp checkpoint & reload UI providers
      await _saveLastSyncAt(syncStartedAt);
      await _transactionProvider.loadTransactions(_userId);
    } catch (e) {
      debugPrint("Sync error encountered: $e");
    }
  }

  Future<DateTime?> getLastSyncAt() async {
    final time = await _getLastSyncAt();
    return time.millisecondsSinceEpoch == 0 ? null : time;
  }

  // ---------- Connectivity Helper ----------

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // ---------- Step 1: Push Local Changes ----------

  Future<void> _pushLocalChanges() async {
    await _pushTransactions();
    await _pushCategories();
    await _pushBudgets();
  }

  Future<void> _pushTransactions() async {
    final pending = await _dbHelper.getPendingTransactions();
    for (final item in pending) {
      try {
        if (item.syncStatus == SyncStatus.pendingDelete) {
          await _firestore.deleteRemoteTransaction(_userId, item.id);
          await _dbHelper.deleteTransaction(item.id);
        } else {
          await _firestore.uploadTransaction(item);
          await _dbHelper.updateTransactionSyncStatus(item.id, SyncStatus.synced);
        }
      } catch (e) {
        debugPrint("Failed to push transaction ${item.id}: $e");
        await _dbHelper.updateTransactionSyncStatus(item.id, SyncStatus.failed);
      }
    }
  }

  Future<void> _pushCategories() async {
    final pending = await _dbHelper.getPendingCategories();
    for (final item in pending) {
      try {
        if (item.syncStatus == SyncStatus.pendingDelete) {
          await _firestore.deleteRemoteCategory(_userId, item.id);
          await _dbHelper.deleteCategory(item.id);
        } else {
          await _firestore.uploadCategory(item);
          await _dbHelper.updateCategorySyncStatus(item.id, SyncStatus.synced);
        }
      } catch (e) {
        debugPrint("Failed to push category ${item.id}: $e");
        await _dbHelper.updateCategorySyncStatus(item.id, SyncStatus.failed);
      }
    }
  }

  Future<void> _pushBudgets() async {
    final pending = await _dbHelper.getPendingBudgets();
    for (final item in pending) {
      try {
        if (item.syncStatus == SyncStatus.pendingDelete) {
          await _firestore.deleteRemoteBudget(_userId, item.id);
          await _dbHelper.deleteBudget(item.id);
        } else {
          await _firestore.uploadBudget(item);
          await _dbHelper.updateBudgetSyncStatus(item.id, SyncStatus.synced);
        }
      } catch (e) {
        debugPrint("Failed to push budget ${item.id}: $e");
        await _dbHelper.updateBudgetSyncStatus(item.id, SyncStatus.failed);
      }
    }
  }

  // ---------- Step 2: Pull Cloud Changes ----------

  Future<void> _pullCloudChanges(DateTime lastSyncAt) async {
    await _pullTransactions(lastSyncAt);
    await _pullCategories(lastSyncAt);
    await _pullBudgets(lastSyncAt);
  }

  Future<void> _pullTransactions(DateTime lastSyncAt) async {
    try {
      final remoteChanges = await _firestore.fetchRemoteChanges(_userId, lastSyncAt);
      for (final remote in remoteChanges) {
        final local = await _dbHelper.getTransactionById(remote.id);
        final resolved = local == null
            ? remote
            : _resolver.resolve(local: local, remote: remote, updatedAtOf: (t) => t.updatedAt);
        await _dbHelper.insertOrUpdateTransaction(resolved.copyWith(syncStatus: SyncStatus.synced));
      }
    } catch (e) {
      debugPrint("Error pulling remote transaction changes: $e");
    }
  }

  Future<void> _pullCategories(DateTime lastSyncAt) async {
    try {
      final remoteChanges = await _firestore.fetchRemoteCategoryChanges(_userId, lastSyncAt);
      for (final remote in remoteChanges) {
        final local = await _dbHelper.getCategoryById(remote.id);
        final resolved = local == null
            ? remote
            : _resolver.resolve(local: local, remote: remote, updatedAtOf: (c) => c.updatedAt);
        await _dbHelper.insertOrUpdateCategory(resolved.copyWith(syncStatus: SyncStatus.synced));
      }
    } catch (e) {
      debugPrint("Error pulling remote category changes: $e");
    }
  }

  Future<void> _pullBudgets(DateTime lastSyncAt) async {
    try {
      final remoteChanges = await _firestore.fetchRemoteBudgetChanges(_userId, lastSyncAt);
      for (final remote in remoteChanges) {
        final local = await _dbHelper.getBudgetById(remote.id);
        final resolved = local == null
            ? remote
            : _resolver.resolve(local: local, remote: remote, updatedAtOf: (b) => b.updatedAt);
        await _dbHelper.insertOrUpdateBudget(resolved.copyWith(syncStatus: SyncStatus.synced));
      }
    } catch (e) {
      debugPrint("Error pulling remote budget changes: $e");
    }
  }

  // ---------- Step 3: Persist User-Scoped lastSyncAt ----------

  Future<DateTime> _getLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_userLastSyncKey);
    return stored != null ? DateTime.parse(stored) : DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _saveLastSyncAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userLastSyncKey, time.toIso8601String());
  }
}