import '../local/db_helper.dart';
import '../models/budget_model.dart';
import '../models/sync_status.dart';

abstract class BudgetRepository {
  Future<List<BudgetModel>> getBudgets(String userId);
  Future<void> addBudget(BudgetModel budget);
  Future<void> updateBudget(BudgetModel budget);
  Future<void> deleteBudget(String id);
}

class LocalBudgetRepository implements BudgetRepository {
  LocalBudgetRepository({DBHelper? dbHelper})
      : _dbHelper = dbHelper ?? DBHelper.instance;

  final DBHelper _dbHelper;

  @override
  Future<List<BudgetModel>> getBudgets(String userId) {
    return _dbHelper.getAllActiveBudgets(userId);
  }

  @override
  Future<void> addBudget(BudgetModel budget) {
    final toSave = budget.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingCreate,
    );
    return _dbHelper.insertOrUpdateBudget(toSave);
  }

  @override
  Future<void> updateBudget(BudgetModel budget) {
    final toSave = budget.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingUpdate,
    );
    return _dbHelper.insertOrUpdateBudget(toSave);
  }

  @override
  Future<void> deleteBudget(String id) {
    return _dbHelper.softDeleteBudget(id);
  }
}
