import '../local/db_helper.dart';
import '../models/sync_status.dart';
import '../models/transaction_model.dart';

abstract class TransactionRepository {
  Future<List<TransactionModel>> getTransactions(String userId);
  Future<void> addTransaction(TransactionModel transaction);
  Future<void> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(String id);
  Future<void> restoreTransaction(TransactionModel transaction);
  Future<List<TransactionModel>> getPendingSyncTransactions();
}

class LocalTransactionRepository implements TransactionRepository {
  LocalTransactionRepository({DBHelper? dbHelper})
      : _dbHelper = dbHelper ?? DBHelper.instance;

  final DBHelper _dbHelper;

  @override
  Future<List<TransactionModel>> getTransactions(String userId) {
    return _dbHelper.getAllActiveTransactions(userId);
  }

  @override
  Future<void> addTransaction(TransactionModel transaction) {
    final toSave = transaction.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingCreate,
    );
    return _dbHelper.insertOrUpdateTransaction(toSave);
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) {
    final toSave = transaction.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingUpdate,
    );
    return _dbHelper.insertOrUpdateTransaction(toSave);
  }

  @override
  Future<void> deleteTransaction(String id) {
    return _dbHelper.softDeleteTransaction(id);
  }

  @override
  Future<void> restoreTransaction(TransactionModel transaction) {
    final restored = transaction.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingUpdate,
      clearDeletedAt: true,
    );
    return _dbHelper.insertOrUpdateTransaction(restored);
  }

  @override
  Future<List<TransactionModel>> getPendingSyncTransactions() {
    return _dbHelper.getPendingTransactions();
  }
}